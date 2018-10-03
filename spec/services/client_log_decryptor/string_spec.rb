require 'spec_helper'

describe ClientLogDecryptor::String do
  let(:key){ '65bb9b2174c33d0cd6d04a7045e057e0' }

  describe 'decrypt' do
    let(:string_decryptor){ described_class.new encrypted_line, key }

    context 'when line contains only ascii' do
      let(:encrypted_line) do
        file = File.open('spec/fixtures/log_uploads/app.log', 'r')
        line = file.readline
        file.close
        line
      end

      let(:source_string) do
        '2017-10-09 05:51:42.562-0400 INFO  [helpers.SupportUtils] battery level : 50%; et : ' +
        '1 minute, 6 seconds and 560 milliseconds'
      end

      it 'decrypts string to match source' do
        string_decryptor.decrypt
        expect(string_decryptor.decrypted_line).to eq source_string
      end
    end

    context 'when line contains unicode' do
      let(:encrypted_line) do
        file = File.open('spec/fixtures/log_uploads/app.log', 'r')
        line = file.readlines[53]
        file.close
        line
      end

      let(:source_string) do
        '2017-10-09 05:51:42.691-0400 INFO  [service.NetworkService] Сервис загрузки данных получил ' +
        'новое задание: service.get_planed'
      end

      it 'decrypts string to match source' do
        string_decryptor.decrypt
        expect(string_decryptor.decrypted_line).to eq source_string
      end
    end

    context 'when line is empty' do
      let(:encrypted_line) do
        ''
      end

      let(:source_string) do
        ''
      end

      it 'decrypts doesnt raise error' do
        expect{ string_decryptor.decrypt }.not_to raise_exception
        expect(string_decryptor.decrypted_line).to eq source_string
      end
    end

    context 'when line is nil' do
      let(:encrypted_line) do
        nil
      end

      let(:source_string) do
        ''
      end

      it 'decrypts doesnt raise error' do
        expect{ string_decryptor.decrypt }.not_to raise_exception
        expect(string_decryptor.decrypted_line).to eq source_string
      end
    end

  end
end
