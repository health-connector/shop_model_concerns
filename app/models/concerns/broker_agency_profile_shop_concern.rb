require 'active_support/concern'

module BrokerAgencyProfileShopConcern
  extend ActiveSupport::Concern

  included do
    # has_many employers
    def employer_clients
      return unless (self.class::MARKET_KINDS - ["individual"]).include?(market_kind)
      return @employer_clients if defined? @employer_clients
      @employer_clients = EmployerProfile.find_by_broker_agency_profile(self)
    end

    def linked_employees
      employer_profiles = EmployerProfile.find_by_broker_agency_profile(self)
      emp_ids = employer_profiles.map(&:id)
      linked_employees = Person.where(:'employee_roles.employer_profile_id'.in => emp_ids)
    end
  end

  class_methods do

  end
end
