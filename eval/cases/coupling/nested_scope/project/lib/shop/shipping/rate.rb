module Shop
  module Shipping
    class Rate
      def bill = Billing::Invoice.new(self)
    end
  end
end
