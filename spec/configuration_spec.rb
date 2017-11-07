require 'rails_helper'

RSpec.describe ShopModelConcerns::Configuration do
  describe "#settings" do
    it "returns a Settings object" do
      expect(ShopModelConcerns.configuration.settings).to eq({ :setting_key => "setting_value" })
    end
  end
end
