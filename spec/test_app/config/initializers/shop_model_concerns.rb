ShopModelConcerns.configure do |config|
  config.settings = Settings

  class ShopModelConcerns::TimeKeeper < TimeKeeper
  end

  class ShopModelConcerns::Organization < Organization
  end

  class ShopModelConcerns::WorkflowStateTransition < WorkflowStateTransition
  end
end
