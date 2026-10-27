module Shop
  module Stripe
    class Charge < Shop::Charge
      def sync = Shop::Stripe.client.fetch(id)
    end
  end
end
