module ClientLogDecryptor
  class File
    attr_reader :file, :strings, :key

    def initialize(file, key)
      @file = file
      @key  = key
      @strings = []
    end

    def read(strings_num = 200)
      @strings = file.tail(strings_num).map do |line|
        ClientLogDecryptor::String.new(line, key)
      end
    end

    def read_all
      @strings = file.readlines.map do |line|
        ClientLogDecryptor::String.new(line, key)
      end
    end

  end
end
