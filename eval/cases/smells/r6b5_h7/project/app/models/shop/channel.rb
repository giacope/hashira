module Shop
  class Channel
    def self.deliver(stream, record) = [stream, record]

    def self.deliver_later(stream, record) = [stream, record]
  end
end
