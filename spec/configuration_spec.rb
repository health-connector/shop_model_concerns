require 'rails_helper'

RSpec.describe ShopModelConcerns::Configuration do
  describe "#settings" do
    it "returns a Settings object" do
      expect(ShopModelConcerns.configuration.settings).to be_kind_of(Config::Options)
    end
  end

  describe "#timekeeper" do
    it "returns a TimeKeeper object" do
      TimeKeeper.date_of_record
      expect(ShopModelConcerns.configuration.timekeeper.date_of_record).to be_kind_of(Date)
    end
  end
end
