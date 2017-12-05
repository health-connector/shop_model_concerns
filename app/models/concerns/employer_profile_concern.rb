require 'active_support/concern'

module EmployerProfileConcern
  extend ActiveSupport::Concern

  included do
    include Mongoid::Document
    include Mongoid::Timestamps
    include ConfigAcaLocationConcern

    embedded_in :organization
    attr_accessor :broker_role_id

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

    embeds_one  :inbox, as: :recipient, cascade_callbacks: true
    embeds_one  :employer_profile_account

    embeds_many :documents, as: :documentable

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
