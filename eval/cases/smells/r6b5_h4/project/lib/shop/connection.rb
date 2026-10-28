module Shop
  class Connection
    def initialize(socket, layers)
      @socket = socket
      @layers = layers
    end

    def request(datum)
      stack = @layers.map { |layer| ->(inner) { layer.new(inner) } }.reverse.inject(self) do |inner, wrap|
        wrap.call(inner)
      end
      stack.response_call(stack.request_call(datum))
    end

    def request_call(datum)
      @socket.write(datum[:body])
      datum.merge(response: { body: @socket.read })
    end

    def label(datum) = datum.fetch(:name).to_s

    def response_call(datum)
      datum[:response][:body] = "" if datum.key?(:response_block)
      datum
    end
  end
end
