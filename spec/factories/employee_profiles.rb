FactoryBot.define do
  factory :employer_profile do
    organization            { FactoryBot.build(:organization) }
    entity_kind             "c_corporation"
    sic_code "1111"
  end
end
