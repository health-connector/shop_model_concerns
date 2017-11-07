require 'rails_helper'

RSpec.describe ShopModelConcerns::Configuration do
  describe "#settings" do
    it "returns a Settings object" do
      expect(ShopModelConcerns.configuration.settings).to be_kind_of(Config::Options)
    end
  end

end
