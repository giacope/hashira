module Shop
  class Reader
    def initialize(socket, timeout)
      @socket = socket
      @timeout = timeout
    end

    def read_exactly(size)
      data = +""
      deadline = Time.now + @timeout
      while data.bytesize < size
        remaining = deadline - Time.now
        raise IOError if remaining <= 0

        @socket.wait_readable(remaining)
        chunk = @socket.read_nonblock(size - data.bytesize, exception: false)
        if chunk == :wait_readable
          @socket.wait_readable([deadline - Time.now, 0].max)
        else
          data << chunk
        end
      end
      data
    end
  end
end
