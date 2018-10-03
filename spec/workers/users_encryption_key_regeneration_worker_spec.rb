require 'spec_helper'

describe UsersEncryptionKeyRegenerationWorker do
  let(:business){ create :business }
  before do
    create_list(:user, 3, business_id: business.id)
    create_list(:user, 3)
  end

  subject(:with_biz) { described_class.new.perform(business.id) }
  subject(:without_biz) { described_class.new.perform }

  with_versioning do
    it { expect { with_biz }.to change(::EncryptionKeyVersion, :count).by(3) }
    it { expect { without_biz }.to change(::EncryptionKeyVersion, :count).by(3) }
  end
end
