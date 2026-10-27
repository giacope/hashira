module Shop
  module Stripe
    class Customer < Shop::Customer
      def sync = Shop::Stripe.client.fetch(id)
    end
  end
end
