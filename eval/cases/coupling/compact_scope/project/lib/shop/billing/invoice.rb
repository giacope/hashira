module Shop
  module Billing
    class Invoice
      def initialize(rate) = @rate = rate
      def quote = Shipping::Rate.new
    end
  end
end
