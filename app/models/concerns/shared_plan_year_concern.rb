require 'active_support/concern'

module SharedPlanYearConcern
  extend ActiveSupport::Concern

  included do |base|
    base::PUBLISHED = PUBLISHED
    base::RENEWING = RENEWING
    base::RENEWING_PUBLISHED_STATE = RENEWING_PUBLISHED_STATE
    base::INELIGIBLE_FOR_EXPORT_STATES = INELIGIBLE_FOR_EXPORT_STATES
    base::OPEN_ENROLLMENT_STATE = OPEN_ENROLLMENT_STATE
    base::INITIAL_ELIGIBLE_STATE = INITIAL_ELIGIBLE_STATE
    base::INITIAL_ENROLLING_STATE = INITIAL_ENROLLING_STATE

    # Workflow attributes
    field :aasm_state, type: String, default: :draft

  end

  class_methods do
    PUBLISHED = %w(published enrolling enrolled active suspended)
    RENEWING  = %w(renewing_draft renewing_published renewing_enrolling renewing_enrolled renewing_publish_pending)
    RENEWING_PUBLISHED_STATE = %w(renewing_published renewing_enrolling renewing_enrolled)

    INELIGIBLE_FOR_EXPORT_STATES = %w(draft publish_pending eligibility_review published_invalid canceled renewing_draft suspended terminated application_ineligible renewing_application_ineligible renewing_canceled conversion_expired)

    OPEN_ENROLLMENT_STATE   = %w(enrolling renewing_enrolling)
    INITIAL_ENROLLING_STATE = %w(publish_pending eligibility_review published published_invalid enrolling enrolled)
    INITIAL_ELIGIBLE_STATE  = %w(published enrolling enrolled)
  end
end
