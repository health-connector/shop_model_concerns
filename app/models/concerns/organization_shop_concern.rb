require 'active_support/concern'

module OrganizationShopConcern
  extend ActiveSupport::Concern

  included do
    #Include any modules here
    #Calls to class methods go here
    #to override methods defined via Includes, use class << self
    embeds_one :employer_profile, cascade_callbacks: true, validate: true  ##Shop Concern
    accepts_nested_attributes_for :employer_profile
    after_save :validate_and_send_denial_notice

    scope :by_broker_agency_profile,            ->( broker_agency_profile_id ) { where(:'employer_profile.broker_agency_accounts' => {:$elemMatch => { is_active: true, broker_agency_profile_id: broker_agency_profile_id } }) }
    scope :by_broker_role,                      ->( broker_role_id ){ where(:'employer_profile.broker_agency_accounts' => {:$elemMatch => { is_active: true, writing_agent_id: broker_role_id                   } }) }

  end

  class_methods do
    ## class methods and constants go here
  end

  def validate_and_send_denial_notice
    if employer_profile.present? && primary_office_location.present? && primary_office_location.address.present?
      employer_profile.validate_and_send_denial_notice
    end
  end
end
