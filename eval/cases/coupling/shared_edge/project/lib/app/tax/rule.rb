module App
  module Tax
    class Rule
      def order = Orders::Order.new
      def origin = Orders::Order.new
    end
  end
end
