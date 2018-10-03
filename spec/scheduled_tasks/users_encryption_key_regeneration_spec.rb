require 'spec_helper'

describe UsersEncryptionKeyRegeneration do
  let(:business){ create :business }
  before do
    create_list(:user, 3, business_id: business.id)
    create_list(:user, 3)
  end

  it 'runs encryption key regeneration worker for every business and after all for tops', :aggregate_failures do
    expect(UsersEncryptionKeyRegenerationWorker).to receive(:perform_async).exactly(2).times
    expect(EncryptionKey.count).to eq 6
    expect { described_class.run }.to_not change { EncryptionKey.count }
  end
end
