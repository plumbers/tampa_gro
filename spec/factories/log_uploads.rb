FactoryGirl.define do
  factory :log_upload do
    type 'LogUpload'
    user_id 1
    file { File.open(Rails.root.join('spec/fixtures/logs.zip')) }
  end
end
