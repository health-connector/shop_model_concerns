ShopModelConcerns.configure do |config|
  config.settings = Settings
  config.timekeeper = TimeKeeper

  class ShopModelConcerns::TimeKeeper < TimeKeeper
  end
end
