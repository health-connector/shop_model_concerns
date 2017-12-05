require "shop_model_concerns/engine"

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
    require 'factory_bot_rails'
    require 'money'
    require 'shop_factories'
  end

  class Configuration
    attr_accessor :settings
  end
end
