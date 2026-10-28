module Shop
  class Wired
    def initialize(data)
      @socket = data.fetch(:wire)
    end

    def drain(size)
      chunk = @socket.read_nonblock(size)
      chunk.nil? ? 0 : chunk.bytesize
    end
  end
end
