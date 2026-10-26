module Shop
  module Stripe
    class Refund < Shop::Refund
      def sync = Shop::Stripe.client.fetch(id)
    end
  end
end
