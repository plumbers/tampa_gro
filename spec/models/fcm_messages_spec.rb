require 'spec_helper'

describe FcmMessage, type: :model do

  context 'fcm' do
    let(:sv){ create :sv }
    let(:user){ create :merch, supervisor: sv }
    subject { described_class.new author_id: sv.id }

    it 'is valid with valid attributes', :aggregates_failure do
      expect(subject).to be_valid
      expect(described_class.column_names).to include 'author_id', 'fcm_token_id', 'notification', 'data',
                                                      'options', 'client_device'
    end
    it { expect belong_to(:user) }
    it { expect belong_to(:location) }
  end

end
