require 'active_support/concern'

module CensusEmployeeConcern
  extend ActiveSupport::Concern

  included do |base|
    include AASM

    base::NEWLY_DESIGNATED_STATES = NEWLY_DESIGNATED_STATES
    
    field :is_business_owner, type: Boolean, default: false
    field :hired_on, type: Date
    field :employment_terminated_on, type: Date
    field :coverage_terminated_on, type: Date
    field :aasm_state, type: String
    field :expected_selection, type: String, default: "enroll"

    # Employer for this employee
    field :employer_profile_id, type: BSON::ObjectId

    # Employee linked to this roster record
    field :employee_role_id, type: BSON::ObjectId

    field :cobra_begin_date, type: Date

    embeds_many :workflow_state_transitions, as: :transitional

    validates_presence_of :employer_profile_id, :ssn, :dob, :hired_on, :is_business_owner
    validates :expected_selection,
      inclusion: {in: ENROLL_STATUS_STATES, message: "%{value} is not a valid  expected selection" }

    index({aasm_state: 1})
    index({last_name: 1})
    index({dob: 1})

    index({encrypted_ssn: 1, dob: 1, aasm_state: 1})
    index({employee_role_id: 1}, {sparse: true})
    index({employer_profile_id: 1, encrypted_ssn: 1, aasm_state: 1})
    index({employer_profile_id: 1, last_name: 1, first_name: 1, hired_on: -1 })
    index({employer_profile_id: 1, hired_on: 1, last_name: 1, first_name: 1 })
    index({employer_profile_id: 1, is_business_owner: 1})

    scope :active,            ->{ any_in(aasm_state: EMPLOYMENT_ACTIVE_STATES) }
    scope :terminated,        ->{ any_in(aasm_state: EMPLOYMENT_TERMINATED_STATES) }
    scope :non_terminated,    ->{ where(:aasm_state.nin => EMPLOYMENT_TERMINATED_STATES) }
    scope :newly_designated,  ->{ any_in(aasm_state: NEWLY_DESIGNATED_STATES) }
    scope :linked,            ->{ any_in(aasm_state: LINKED_STATES) }
    scope :eligible,          ->{ any_in(aasm_state: ELIGIBLE_STATES) }
    scope :without_cobra,     ->{ not_in(aasm_state: COBRA_STATES) }
    scope :by_cobra,          ->{ any_in(aasm_state: COBRA_STATES) }
    scope :pending,           ->{ any_in(aasm_state: PENDING_STATES) }
    scope :active_alone,      ->{ any_in(aasm_state: EMPLOYMENT_ACTIVE_ONLY) }

    scope :employee_name, -> (employee_name) { any_of({first_name: /#{employee_name}/i}, {last_name: /#{employee_name}/i}, first_name: /#{employee_name.split[0]}/i, last_name: /#{employee_name.split[1]}/i) }

    scope :sorted,                -> { order(:"census_employee.last_name".asc, :"census_employee.first_name".asc)}
    scope :order_by_last_name,    -> { order(:"census_employee.last_name".asc) }
    scope :order_by_first_name,   -> { order(:"census_employee.first_name".asc) }
    scope :by_ssn,                          ->(ssn) { where(encrypted_ssn: CensusMember.encrypt_ssn(ssn)) }

    scope :by_employer_profile_id,          ->(employer_profile_id) { where(employer_profile_id: employer_profile_id) }
    scope :non_business_owner,              ->{ where(is_business_owner: false) }

    def initialize(*args)
      super(*args)
      write_attribute(:employee_relationship, "self")
    end

    def employee_relationship
      "employee"
    end

    def is_linked?
      LINKED_STATES.include?(aasm_state)
    end

    def is_eligible?
      ELIGIBLE_STATES.include?(aasm_state)
    end

    def employer_profile=(new_employer_profile)
      raise ArgumentError.new("expected EmployerProfile") unless new_employer_profile.is_a?(EmployerProfile)
      self.employer_profile_id = new_employer_profile._id
      @employer_profile = new_employer_profile
    end

    def employer_profile
      return @employer_profile if defined? @employer_profile
      @employer_profile = EmployerProfile.find(self.employer_profile_id) unless self.employer_profile_id.blank?
    end
    aasm do
      state :eligible, initial: true
      state :cobra_eligible
      state :newly_designated_eligible    # congressional employee state with certain new hire rules
      state :employee_role_linked
      state :cobra_linked
      state :newly_designated_linked
      state :cobra_termination_pending
      state :employee_termination_pending
      state :employment_terminated
      state :cobra_terminated
      state :rehired

      event :newly_designate, :after => :record_transition do
        transitions from: :eligible, to: :newly_designated_eligible
        transitions from: :employee_role_linked, to: :newly_designated_linked
      end

      event :rebase_new_designee, :after => :record_transition do
        transitions from: :newly_designated_eligible, to: :eligible
        transitions from: :newly_designated_linked, to: :employee_role_linked
      end

      event :rehire_employee_role, :after => :record_transition do
        transitions from: [:employment_terminated, :cobra_eligible, :cobra_linked, :cobra_terminated], to: :rehired
      end

      event :elect_cobra, :guard => :have_valid_date_for_cobra?, :after => :record_transition do
        transitions from: :employment_terminated, to: :cobra_linked, :guard => :has_employee_role_linked?, after: :build_hbx_enrollment_for_cobra
        transitions from: :employment_terminated, to: :cobra_eligible
      end

      event :link_employee_role, :after => :record_transition do
        transitions from: :eligible, to: :employee_role_linked, :guard => :has_benefit_group_assignment?
        transitions from: :cobra_eligible, to: :cobra_linked, guard: :has_benefit_group_assignment?
        transitions from: :newly_designated_eligible, to: :newly_designated_linked, :guard => :has_benefit_group_assignment?
      end

      event :delink_employee_role, :guard => :has_no_hbx_enrollments?, :after => :record_transition do
        transitions from: :employee_role_linked, to: :eligible, :after => :clear_employee_role
        transitions from: :newly_designated_linked, to: :newly_designated_eligible, :after => :clear_employee_role
        transitions from: :cobra_linked, to: :cobra_eligible, after: :clear_employee_role
      end

      event :schedule_employee_termination, :after => :record_transition do
        transitions from: [:employee_termination_pending, :eligible, :employee_role_linked, :newly_designated_eligible, :newly_designated_linked], to: :employee_termination_pending
        transitions from: [:cobra_termination_pending, :cobra_eligible, :cobra_linked],  to: :cobra_termination_pending
      end

      event :terminate_employee_role, :after => :record_transition do
        transitions from: [:eligible, :employee_role_linked, :employee_termination_pending, :newly_designated_eligible, :newly_designated_linked], to: :employment_terminated
        transitions from: [:cobra_eligible, :cobra_linked, :cobra_termination_pending],  to: :cobra_terminated
      end

      event :reinstate_eligibility, :after => [:record_transition] do
        transitions from: :employment_terminated, to: :employee_role_linked, :guard => :has_employee_role_linked?
        transitions from: :employment_terminated,  to: :eligible
        transitions from: :cobra_terminated, to: :cobra_linked, :guard => :has_employee_role_linked?
        transitions from: :cobra_terminated, to: :cobra_eligible
      end
    end

    class << self
      def find_all_by_employer_profile(employer_profile)
        unscoped.where(employer_profile_id: employer_profile._id).order_name_asc
      end
      alias_method :find_by_employer_profile, :find_all_by_employer_profile

    end

    private
      def record_transition
        self.workflow_state_transitions << WorkflowStateTransition.new(
          from_state: aasm.from_state,
          to_state: aasm.to_state
        )
      end
  end

  class_methods do
    EMPLOYMENT_ACTIVE_STATES = %w(eligible employee_role_linked employee_termination_pending newly_designated_eligible newly_designated_linked cobra_eligible cobra_linked cobra_termination_pending)
    EMPLOYMENT_TERMINATED_STATES = %w(employment_terminated cobra_terminated rehired)
    EMPLOYMENT_ACTIVE_ONLY = %w(eligible employee_role_linked employee_termination_pending newly_designated_eligible newly_designated_linked)
    NEWLY_DESIGNATED_STATES = %w(newly_designated_eligible newly_designated_linked)
    LINKED_STATES = %w(employee_role_linked newly_designated_linked cobra_linked)
    ELIGIBLE_STATES = %w(eligible newly_designated_eligible cobra_eligible employee_termination_pending cobra_termination_pending)
    COBRA_STATES = %w(cobra_eligible cobra_linked cobra_terminated cobra_termination_pending)
    PENDING_STATES = %w(employee_termination_pending cobra_termination_pending)
    ENROLL_STATUS_STATES = %w(enroll waive will_not_participate)

    EMPLOYEE_TERMINATED_EVENT_NAME = "acapi.info.events.census_employee.terminated"
    EMPLOYEE_COBRA_TERMINATED_EVENT_NAME = "acapi.info.events.census_employee.cobra_terminated"
  end
end
