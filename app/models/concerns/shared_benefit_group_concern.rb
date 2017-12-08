require 'active_support/concern'

module SharedBenefitGroupConcern
  extend ActiveSupport::Concern

  included do |base|
    include Mongoid::Document
    include Mongoid::Timestamps

    base::PLAN_OPTION_KINDS = PLAN_OPTION_KINDS

    field :title, type: String, default: ""
    field :description, type: String, default: ""

    validates_uniqueness_of :title

    validates_presence_of :plan_option_kind

    validates :plan_option_kind,
    allow_blank: false,
    inclusion: {
      in: base::PLAN_OPTION_KINDS,
      message: "%{value} is not a valid plan option kind"
    }
  end

  class_methods do
    PLAN_OPTION_KINDS = %w(sole_source single_plan single_carrier metal_level)

  end
end
