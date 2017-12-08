require 'active_support/concern'

module BenefitGroupConcern
  extend ActiveSupport::Concern

  included do
    include SharedBenefitGroupConcern
  end

  class_methods do

  end
end
