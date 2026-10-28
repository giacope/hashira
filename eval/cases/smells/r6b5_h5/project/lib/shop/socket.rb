module Shop
  class Socket
    def initialize(data)
      @data = data
      @buffer = +""
    end

    def connect
      socket = ::Socket.new(:INET, :STREAM)
      socket.connect(@data[:address])
      @socket = socket
    end

    def read_nonblock(size)
      @buffer << @socket.read_nonblock(size)
      @buffer.empty? ? nil : @buffer.slice!(0, size)
    end
  end
end
