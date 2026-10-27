module Shop
  module Stripe
    class Charge < Shop::Charge
      def sync = Shop::Stripe.client.fetch(id)

      def warn = Shop::Alert.create!(charge: self)
    end
  end
end
