require 'active_support/concern'

module ShopTimeKeeperConcern
  extend ActiveSupport::Concern

  included do

  end

  class_methods do

  end

  def push_date_of_record
    EmployerProfile.advance_day(self.date_of_record)
    super
  end
end
