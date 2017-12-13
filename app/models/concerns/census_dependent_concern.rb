require 'active_support/concern'

module CensusDependentConcern
  extend ActiveSupport::Concern

  included do |base|
    base::EMPLOYEE_RELATIONSHIP_KINDS = EMPLOYEE_RELATIONSHIP_KINDS

    embedded_in :census_employee,
      class_name: parent_member_class

    validates :employee_relationship,
                presence: true,
                allow_blank: false,
                allow_nil:   false,
                inclusion: {
                  in: base::EMPLOYEE_RELATIONSHIP_KINDS,
                  message: "'%{value}' is not a valid employee relationship"
                }

    def parent
      self.census_employee
    end
  end

  class_methods do
    EMPLOYEE_RELATIONSHIP_KINDS = %W[spouse domestic_partner child_under_26  child_26_and_over disabled_child_26_and_over]

    def parent_member_class
      'CensusEmployee'
    end
  end
end
