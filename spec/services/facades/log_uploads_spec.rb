require 'spec_helper'
require Rails.root + 'app/services/client_log_decryptor'

describe Facades::LogUploads do
  let!(:merch){ create(:merch) }
  let!(:key) do
    key = merch.encryption_key
    key.update! random_key: '4a7c8401fa1151b1d06cfc71140a5209'
    key
  end
  let(:user){ create(:content_manager) }
  let(:log_upload){ create(:log_upload, encryption_key_version: key.key_version, user_id: merch.id,
                           file: File.open('spec/fixtures/log_uploads/logs.zip')) }
  let(:file_names){ ['app.log', 'sfa.log'] }
  let(:context) { OpenStruct.new(params: { id: log_upload.id }, current_user: user) }

  let!(:facade){ described_class.new(context) }

  shared_examples_for :unzip do
    it 'saves each zip stream to @decryptors' do
      decryptors = facade.instance_variable_get('@decryptors')
      expect(decryptors.keys).to match_array file_names
      expect(decryptors.values.map(&:class)).to match_array([ClientLogDecryptor::File, ClientLogDecryptor::File])
    end
  end

  shared_context :stubs do
    let!(:decryptor_class){ class_double("ClientLogDecryptor::File").as_stubbed_const(transfer_nested_constants: true) }
    let!(:decryptor){ instance_double("ClientLogDecryptor::File") }
    let!(:str_class){ class_double("ClientLogDecryptor::String").as_stubbed_const(transfer_nested_constants: true) }
    let!(:str){ instance_double("ClientLogDecryptor::String") }

    before do
      allow(decryptor_class).to receive(:new).and_return(decryptor)
      allow(decryptor).to receive(:read).with(described_class::SHOW_LIMIT)
      allow(decryptor).to receive(:read_all)
      allow(decryptor).to receive(:strings).and_return [str, str]
      allow(str_class).to receive(:new)
      allow(str).to receive(:decrypt)
    end
  end

  describe '#show' do

    describe 'method calls' do
      include_context :stubs

      it 'calls ClientLogDecryptor::File#read with specified limit' do
        expect(decryptor).to receive(:read).twice.with(200)
        facade.show
      end

      context 'when block given' do

        it 'calls ClientLogDecryptor::File#strings' do
          expect(decryptor).to receive(:strings).twice
          facade.show{}
        end
      end
    end

    describe 'unzip' do
      before { facade.show }
      include_examples :unzip
    end

    it 'yields names and strings array' do
      expect{ |b | facade.show(&b) }.to yield_successive_args(['app.log', Array], ['sfa.log', Array])
    end

  end

  describe '#names' do

    before { facade.names }
    include_examples :unzip

    it 'returns zipped files names' do
      expect(facade.names).to match_array file_names
    end
  end

  describe '#send_file' do

    describe 'method calls' do
      include_context :stubs

      it 'calls ClientLogDecryptor::File#read with specified limit' do
        expect(decryptor).to receive(:read_all).twice
        facade.send_file
      end

      it 'calls ClientLogDecryptor::File#strings' do
        expect(decryptor).to receive(:strings).twice
        facade.send_file
      end
    end

    describe 'unzip' do
      before { facade.send_file }
      include_examples :unzip
    end

    it 'returns zip io' do
      expect(facade.send_file).to be_a(StringIO)
      zip = Zip::File.open_buffer(facade.send_file)
      expect(zip.map(&:class)).to match_array [Zip::Entry, Zip::Entry]
      expect(zip.map(&:name)).to match_array file_names
    end
  end

end
