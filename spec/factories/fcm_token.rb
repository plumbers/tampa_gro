FactoryGirl.define do
  factory :fcm_token do
    key { Faker::Name.name }
    user
  end
end
