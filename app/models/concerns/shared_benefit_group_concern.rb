require 'active_support/concern'

module SharedBenefitGroupConcern
  extend ActiveSupport::Concern

  included do |base|
    include Mongoid::Document
    include Mongoid::Timestamps

    base::PLAN_OPTION_KINDS = PLAN_OPTION_KINDS
    embedded_in :plan_year

    field :title, type: String, default: ""
    field :description, type: String, default: ""
  end

  class_methods do
    PLAN_OPTION_KINDS = %w(sole_source single_plan single_carrier metal_level)

  end
end
