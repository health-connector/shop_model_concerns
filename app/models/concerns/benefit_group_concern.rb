require 'active_support/concern'

module BenefitGroupConcern
  extend ActiveSupport::Concern

  included do
    include SharedBenefitGroupConcern

    embedded_in :plan_year
  end

  class_methods do

  end
end
