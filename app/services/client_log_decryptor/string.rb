module ClientLogDecryptor
  class String

    class EmptyLineError < StandardError; end

    attr_reader :line, :key, :decoded_line, :decrypted_line

    def initialize(line, key)
      @line = line
      @key  = (key.kind_of?(String) && 32 != key.bytesize) ? Digest::SHA256.digest(key) : key
      @decrypted_line = nil
    end

    def decrypt(force = false)
      return @decrypted_line if @decrypted_line && !force
      return @decrypted_line = encode(decoded_line) if decoded_line.empty?

      decipher = OpenSSL::Cipher::AES256.new(:CBC)
      decipher.decrypt
      decipher.key = key

      encode begin
        @decrypted_line = (decipher.update(decoded_line) + decipher.final)
      rescue OpenSSL::Cipher::CipherError
        @decrypted_line = decoded_line
      end

    end

    def decoded_line
      @decoded_line ||= line.nil? ? '' : Base64.decode64(line)
    end

    def encode(str)
      str.force_encoding('UTF-8').encode
    end
  end
end
