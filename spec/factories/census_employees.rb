FactoryBot.define do
  factory :census_employee do
    first_name "Eddie"
    sequence(:last_name) {|n| "Vedder#{n}" }
    dob "1964-10-23".to_date
    gender "male"
    expected_selection "enroll"
    employee_relationship "self"
    hired_on "2015-04-01".to_date
    sequence(:ssn) { |n| 222222220 + n }
    is_business_owner  false
    association :address, strategy: :build
    association :email, strategy: :build
    association :employer_profile, strategy: :build

    transient do
      create_with_spouse false
    end

    after(:create) do |census_employee, evaluator|
      census_employee.created_at = TimeKeeper.date_of_record
      if evaluator.create_with_spouse
        census_employee.census_dependents << create(:census_member, employee_relationship: 'spouse')
      end
    end
  end
end
