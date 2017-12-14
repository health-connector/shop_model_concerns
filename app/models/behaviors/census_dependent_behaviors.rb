require 'active_support/concern'

module Behaviors
  module CensusDependentBehaviors
    extend ActiveSupport::Concern

    included do
      embeds_many :census_dependents,
        class_name: dependent_class,
        cascade_callbacks: true,
        validate: true

      accepts_nested_attributes_for :census_dependents

      def initialize(*args)
        super(*args)
        write_attribute(:employee_relationship, "self")
      end

      def employee_relationship
        "employee"
      end

      def composite_rating_tier
        return CompositeRatingTier::EMPLOYEE_ONLY if self.census_dependents.empty?
        relationships = self.census_dependents.map(&:employee_relationship)
        if (relationships.include?("spouse") || relationships.include?("domestic_partner"))
          relationships.many? ? CompositeRatingTier::FAMILY : CompositeRatingTier::EMPLOYEE_AND_SPOUSE
        else
          CompositeRatingTier::EMPLOYEE_AND_ONE_OR_MORE_DEPENDENTS
        end
      end
    end

    class_methods do
      unless self.respond_to?(:dependent_class)
        def dependent_class
          'CensusDependent'
        end
      end
    end
  end
end
