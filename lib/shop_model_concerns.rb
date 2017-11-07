require "shop_model_concerns/engine"
require 'factory_bot_rails'
require 'factories'

module ShopModelConcerns
  class << self
    attr_writer :configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.reset
    @configuration = Configuration.new
  end

  def self.configure
    yield(configuration)
  end

  class Configuration
    attr_accessor :settings, :timekeeper
  end
end
