module Shop
  module Layers
    class Strip < Base
      def response_call(datum)
        datum[:body] = datum[:body].to_s.strip
        @stack.response_call(datum)
      end
    end
  end
end
