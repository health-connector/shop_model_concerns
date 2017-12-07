require 'active_support/concern'

module OrganizationShopConcern
  extend ActiveSupport::Concern

  included do
    #Include any modules here
    #Calls to class methods go here
    #to override methods defined via Includes, use class << self
    after_save :validate_and_send_denial_notice
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
