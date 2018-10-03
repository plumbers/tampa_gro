require 'spec_helper'

describe ClientLogDecryptor::File do
  let(:key){ '65bb9b2174c33d0cd6d04a7045e057e0' }

  context 'when handling zip io' do
    let(:zip_io){ @io = Zip::File.open('spec/fixtures/log_uploads/logs.zip'); @io.first.get_input_stream }
    after{ @io.close }
    let(:decryptor){ described_class.new zip_io, key }

    describe 'reading with tail' do
      context 'with default limit' do
        it 'reads default strings limit' do
          decryptor.read
          expect(decryptor.strings.size).to eq 200
        end

      end

      context 'with given limit' do
        it 'reads given strings limit' do
          decryptor.read(220)
          expect(decryptor.strings.size).to eq 220
        end
      end
    end

    describe 'reading all strings' do
      it 'reads all strings' do
        decryptor.read_all
        zip_io.rewind
        expect(decryptor.strings.size).to eq zip_io.readlines.size
      end
    end

    describe 'string class' do
      it 'sets correct class for each read string' do
        decryptor.read_all
        expect(decryptor.strings.map(&:class).uniq).to match_array [ClientLogDecryptor::String]
      end

    end

  end

  context 'when handling regular io' do
    let(:io){ File.open('spec/fixtures/log_uploads/app.log') }
    after{ io.close }
    let(:decryptor){ described_class.new io, key }

    describe 'read' do
      it 'doesnt raise error' do
        expect{ decryptor.read }.not_to raise_error
      end
    end

    describe 'read_all' do
      it 'doesnt raise error' do
        expect{ decryptor.read_all }.not_to raise_error
      end
    end

  end


end
