require 'spec_helper'

describe EncryptionKey, type: :model do
  let!(:business){ create :business }
  let!(:user){ create :user, business_id: business.id }

  describe 'use cases' do
    it 'should create a new instance' do
      expect { create :user }.to change { described_class.count }.by(1)
    end
    it 'should not create a new key, but new version when admin regenerate key' do
      expect { user.encryption_key.regenerate! }.to_not change {  described_class.count }
    end
  end

  describe 'versioning' do
    with_versioning do

      let!(:merch){ create :merch, business_id: business.id }
      let(:key){ merch.encryption_key }
      let!(:key_version_attrs){ {
          'key_length'  => [nil, 128], 'key_type' => [nil, 'CBC'],
          'random_key'  => [nil, key.random_key], 'random_iv' => [nil, key.random_iv],
          'key_version' => [nil, key.key_version] } }
      let(:version){ merch.encryption_key.current_version }

      context 'for created user', :aggregate_failures do
        it 'define valid :create event version' do
          expect(version.event).to eq 'create'
          expect(version.object).to be_nil
          expect(version.object_changes).to include key_version_attrs
        end
        it 'define valid :update event version' do
          key.regenerate!
          expect(version.event).to eq 'update'
          expect(version.object).to_not be_nil
          expect(version.object_changes.keys).to include('random_key', 'random_iv')
        end
      end

      context 'on regenerate' do
        it 'creates new version' do
          old_key = key.dup
          key.regenerate!
          expect(key).to have_a_version_with_changes(random_key: old_key.random_key, random_key: key.random_key)
        end
      end

      context 'key version store changes in time' do
        let(:time_traveler_merch){ create :merch, business_id: business.id }
        let(:key){ time_traveler_merch.encryption_key }
        before do
          ::EncryptionKeyVersion.destroy_all
          Timecop.travel '2001-01-01' do
            key.regenerate!
            expect(Time.at key.key_version).to be_within(10.second).of Time.now
            @key_v1 = key.dup
          end
          Timecop.travel '2001-01-11' do
            key.regenerate!
            expect(Time.at key.key_version).to be_within(10.second).of Time.now
            @key_v2 = key.dup
          end
        end
        it 'save/load correct unix time version', :aggregate_failures  do
          expect(::EncryptionKeyVersion.count).to eq 2

          key_versions = key.versions.map(&:actual_attr_set).map{ |h| h['key_version'] }
          key_versions.each do |key_version|
            expect(key.invoke_key_by(key_version).random_key).to_not be_nil
          end
          expect(key_versions[0..1]).to match_array [@key_v1.key_version, @key_v2.key_version]

          expect(key.invoke_key_by(@key_v1.key_version).random_key).to eq @key_v1.random_key
          expect(key.invoke_key_by(@key_v2.key_version).random_key).to eq @key_v2.random_key

          expect(key.invoke_key_by(nil).key_version).to eq EncryptionKey.last.key_version
        end

      end

    end
  end
end
