require 'spec_helper'

def encryption_attrs(response)
  JSON.parse(response.body).select { |v| v=~/encryption/ }.values
end

describe 'EncryptionController API v9', type: [:request, :model] do
  before { allow_any_instance_of(User).to receive(:paid_account?).and_return(true) }

  let!(:user) { create(:merch) }

  include_context 'api_shared_variables', 9
  with_versioning do

    it 'returns key without version in params' do
      key_value   = user.encryption_key.random_key
      key_version = user.encryption_key.key_version

      get '/api/encryption/key.json', params: {}, headers: version_and_auth_header

      expect(encryption_attrs(response)).to match_array [key_version, key_value]
    end

    it 'returns key by version', :aggregate_failures do
      old_key  = user.encryption_key.dup
      sleep 0.003
      user.encryption_key.regenerate!
      new_key = user.encryption_key
      get '/api/encryption/key.json', params: { version: old_key.key_version }, headers: version_and_auth_header

      expect(encryption_attrs(response)).to     match_array [old_key.key_version, old_key.random_key]
      expect(encryption_attrs(response)).to_not match_array [new_key.key_version, new_key.random_key]
    end

    it 'returns NotFound when such version of key not exists', :expect_failure  do
      get '/api/encryption/key.json', params: { version: 123 }, headers: version_and_auth_header
      expect(response.status).to eq 404
    end

  end

end
