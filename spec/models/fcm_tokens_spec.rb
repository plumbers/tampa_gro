require 'spec_helper'

describe FcmToken, type: :model do

  context 'fcm' do
    let(:user){ create :merch }
    subject { described_class.new user_id: user.id, key: 'fcm_token.key/client_id/registration_id' }

    it 'is valid with valid attributes', :aggregates_failure do
      expect(subject).to be_valid
      expect(described_class.column_names).to include 'key', 'user_id'
    end
    it { expect belong_to(:user) }
  end

end
