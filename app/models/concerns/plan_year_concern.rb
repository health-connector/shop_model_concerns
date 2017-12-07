require 'active_support/concern'

module PlanYearConcern
  extend ActiveSupport::Concern

  included do
    include SharedPlanYearConcern
  end

  class_methods do

  end
end
