require 'active_support/concern'

module BrokerAgencyAccountShopConcern
  extend ActiveSupport::Concern

  included do
    embedded_in :employer_profile
  end

  class_methods do

  end
end
