module Shop
  module SOCKS5
    def read_exactly(size)
      data = +""
      while data.bytesize < size
        chunk = @socket.read_nonblock(size - data.bytesize, exception: false)
        case chunk
        when :wait_readable then @socket.wait_readable
        when nil, "" then raise EOFError
        else data << chunk
        end
      end
      data
    end
  end
end
