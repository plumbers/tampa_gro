module Facades
  class LogUploads < Base
    SHOW_LIMIT = 200

    def initialize(view_context, object = nil)
      super
      @decryptors = {}
    end

    def show
      unzip
      @decryptors.each do |name, decr|
        decr.read(SHOW_LIMIT)
        yield name, decr.strings.map(&:decrypt) if block_given?
      end
    ensure
      @io.close
    end

    def send_file
      unzip
      zip = Zip::OutputStream.new(StringIO.new, true)
      @decryptors.each do |name, decr|
        decr.read_all
        add_entry(zip, name, decr)
      end
      stream = zip.close_buffer
      stream.rewind
      stream
    ensure
      @io.close
    end

    def upload
      @upload ||= LogUpload.find(params[:id])
    end

    def names
      unzip
      @decryptors.keys
    end

    private

    def add_entry(zip, name, decr)
      entry = Zip::Entry.new("", name, "", "", 0, 0, Zip::Entry::DEFLATED, 0, Zip::DOSTime.at(Time.now.to_i))
      zip.put_next_entry(entry)
      zip.puts(*decr.strings.map(&:decrypt))
      zip
    end

    def unzip
      return if @unzipped
      @io = Zip::File.open(upload.file.path)
      @io.each do |entry|
        decr = ClientLogDecryptor::File.new(entry.get_input_stream, key)
        @decryptors[entry.name] = decr
        yield decr if block_given?
      end
      @unzipped = true
    end

    def key
      @key ||= EncryptionKey.find_by(key_version: upload.encryption_key_version, user_id: upload.user_id).random_key
    end

  end
end
