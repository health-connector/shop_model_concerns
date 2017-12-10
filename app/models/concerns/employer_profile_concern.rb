require 'active_support/concern'

module EmployerProfileConcern
  extend ActiveSupport::Concern

  included do
    include Mongoid::Document
    include Mongoid::Timestamps
    include AASM
    include ConfigAcaLocationConcern

    embedded_in :organization
    attr_accessor :broker_role_id

    embeds_one  :inbox, as: :recipient, cascade_callbacks: true
    embeds_one  :employer_profile_account

    embeds_many :documents, as: :documentable
    embeds_many :plan_years, cascade_callbacks: true, validate: true
    embeds_many :broker_agency_accounts, cascade_callbacks: true, validate: true
    embeds_many :workflow_state_transitions, as: :transitional

    accepts_nested_attributes_for :plan_years, :inbox, :employer_profile_account, :broker_agency_accounts

    field :entity_kind, type: String
    field :sic_code, type: String

  #  field :converted_from_carrier_at, type: DateTime, default: nil
  #  field :conversion_carrier_id, type: BSON::ObjectId, default: nil

    # Workflow attributes
    field :aasm_state, type: String, default: "applicant"

    field :profile_source, type: String, default: "self_serve"
    field :contact_method, type: String, default: "Only Electronic communications"
    field :registered_on, type: Date, default: ->{ TimeKeeper.date_of_record }
    field :xml_transmitted_timestamp, type: DateTime

    delegate :hbx_id, to: :organization, allow_nil: true
    delegate :issuer_assigned_id, to: :organization, allow_nil: true
    delegate :legal_name, :legal_name=, to: :organization, allow_nil: true
    delegate :dba, :dba=, to: :organization, allow_nil: true
    delegate :fein, :fein=, to: :organization, allow_nil: true
    delegate :is_active, :is_active=, to: :organization, allow_nil: false
    delegate :updated_by, :updated_by=, to: :organization, allow_nil: false

    validates_presence_of :entity_kind
    validates_presence_of :sic_code
    validates_presence_of :contact_method

    validates :profile_source,
      inclusion: { in: EmployerProfile::PROFILE_SOURCE_KINDS },
      allow_blank: false

    validates :entity_kind,
      inclusion: { in: Organization::ENTITY_KINDS, message: "%{value} is not a valid business entity kind" },
      allow_blank: false

    after_initialize :build_nested_models
    after_save :save_associated_nested_models

    scope :active,      ->{ any_in(aasm_state: ACTIVE_STATES) }
    scope :inactive,    ->{ any_in(aasm_state: INACTIVE_STATES) }

    scope :all_renewing, ->{ Organization.all_employers_renewing }
    scope :all_with_next_month_effective_date,  ->{ Organization.all_employers_by_plan_year_start_on(TimeKeeper.date_of_record.end_of_month + 1.day) }

    alias_method :is_active?, :is_active

    def parent
      raise "undefined parent Organization" unless organization?
      organization
    end

    aasm do
      state :applicant, initial: true
      state :registered                 # Employer has submitted valid application
      state :eligible                   # Employer has completed enrollment and is eligible for coverage
      state :binder_paid, :after_enter => [:notify_binder_paid,:notify_initial_binder_paid,:transmit_new_employer_if_immediate]
      state :enrolled                   # Employer has completed eligible enrollment, paid the binder payment and plan year has begun
      # state :lapsed                     # Employer benefit coverage has reached end of term without renewal
      state :suspended                  # Employer's benefit coverage has lapsed due to non-payment
      state :ineligible                 # Employer is unable to obtain coverage on the HBX per regulation or policy

      event :advance_date do
        transitions from: :ineligible, to: :applicant, :guard => :has_ineligible_period_expired?
      end

      event :application_accepted, :after => :record_transition do
        transitions from: [:registered], to: :registered
        transitions from: [:applicant, :ineligible], to: :registered
      end

      event :application_declined, :after => :record_transition do
        transitions from: :applicant, to: :ineligible
        transitions from: :ineligible, to: :ineligible
      end

      event :application_expired, :after => :record_transition do
        transitions from: :registered, to: :applicant
      end

      event :enrollment_ratified, :after => :record_transition do
        transitions from: [:registered, :ineligible], to: :eligible, :after => :initialize_account
      end

      event :enrollment_expired, :after => :record_transition do
        transitions from: :eligible, to: :applicant
      end

      event :binder_credited, :after => :record_transition do
        transitions from: :eligible, to: :binder_paid
      end

      event :binder_reversed, :after => :record_transition do
        transitions from: :binder_paid, to: :eligible
      end

      event :enroll_employer, :after => :record_transition do
        transitions from: :binder_paid, to: :enrolled
      end

      event :enrollment_denied, :after => :record_transition do
        transitions from: [:registered, :enrolled], to: :applicant
      end

      event :benefit_suspended, :after => :record_transition do
        transitions from: :enrolled, to: :suspended, :after => :suspend_benefit
      end

      event :employer_reinstated, :after => :record_transition do
        transitions from: :suspended, to: :enrolled
      end

      event :benefit_terminated, :after => :record_transition do
        transitions from: [:enrolled, :suspended], to: :applicant
      end

      event :benefit_canceled, :after => :record_transition do
        transitions from: :eligible, to: :applicant, :after => :cancel_benefit
      end

      # Admin capability to reset an Employer to applicant state
      event :revert_application, :after => :record_transition do
        transitions from: [:registered, :eligible, :ineligible, :suspended, :binder_paid, :enrolled], to: :applicant
      end

      event :force_enroll, :after => :record_transition do
        transitions from: [:applicant, :eligible, :registered], to: :enrolled
      end
    end

    class << self
      def list_embedded(parent_list)
        parent_list.reduce([]) { |list, parent_instance| list << parent_instance.employer_profile }
      end

      def all
        list_embedded Organization.exists(employer_profile: true).order_by([:legal_name]).to_a
      end

      def first
        all.first
      end

      def last
        all.last
      end

      def find(id)
        organizations = Organization.where("employer_profile._id" => BSON::ObjectId.from_string(id))
        organizations.size > 0 ? organizations.first.employer_profile : nil
      rescue
        log("Can not find employer_profile with id #{id}", {:severity => "error"})
        nil
      end

      def find_by_fein(fein)
        organization = Organization.where(fein: fein).first
        organization.present? ? organization.employer_profile : nil
      end

      def find_by_broker_agency_profile(broker_agency_profile)
        raise ArgumentError.new("expected BrokerAgencyProfile") unless broker_agency_profile.is_a?(BrokerAgencyProfile)
        orgs = Organization.by_broker_agency_profile(broker_agency_profile.id)
        orgs.collect(&:employer_profile)
      end
    end
  end

  class_methods do
    BINDER_PREMIUM_PAID_EVENT_NAME = "acapi.info.events.employer.binder_premium_paid"
    EMPLOYER_PROFILE_UPDATED_EVENT_NAME = "acapi.info.events.employer.updated"
    INITIAL_APPLICATION_ELIGIBLE_EVENT_TAG="benefit_coverage_initial_application_eligible"
    INITIAL_EMPLOYER_TRANSMIT_EVENT="acapi.info.events.employer.benefit_coverage_initial_application_eligible"
    RENEWAL_APPLICATION_ELIGIBLE_EVENT_TAG="benefit_coverage_renewal_application_eligible"
    RENEWAL_EMPLOYER_TRANSMIT_EVENT="acapi.info.events.employer.benefit_coverage_renewal_application_eligible"

    ACTIVE_STATES   = ["applicant", "registered", "eligible", "binder_paid", "enrolled"]
    INACTIVE_STATES = ["suspended", "ineligible"]

    PROFILE_SOURCE_KINDS  = ["self_serve", "conversion"]

    INVOICE_VIEW_INITIAL  = %w(published enrolling enrolled active suspended)
    INVOICE_VIEW_RENEWING = %w(renewing_published renewing_enrolling renewing_enrolled renewing_draft)

    ENROLLED_STATE = %w(enrolled suspended)

    def by_hbx_id(an_hbx_id)
      org = Organization.where(hbx_id: an_hbx_id, employer_profile: {"$exists" => true})
      return nil unless org.any?
      org.first.employer_profile
    end

    def update_status_to_binder_paid(organization_ids)
      organization_ids.each do |id|
        if org = Organization.find(id)
          org.employer_profile.update_attribute(:aasm_state, "binder_paid")
        end
      end
    end

  end
end
