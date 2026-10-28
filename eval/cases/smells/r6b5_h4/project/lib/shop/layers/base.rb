module Shop
  module Layers
    class Base
      def initialize(stack)
        @stack = stack
      end

      def request_call(datum) = @stack.request_call(datum)

      def response_call(datum) = @stack.response_call(datum)
    end
  end
end
