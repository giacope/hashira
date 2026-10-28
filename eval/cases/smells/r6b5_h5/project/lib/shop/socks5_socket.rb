module Shop
  class SOCKS5Socket < Socket
    include SOCKS5

    def connect
      super
      read_exactly(2)
    end
  end
end
