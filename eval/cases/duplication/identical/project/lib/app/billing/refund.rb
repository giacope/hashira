module App
  module Billing
    class Refund
      def run(gateway)
        gateway.configure(fetch(:host), fetch(:port))
        gateway.connect(retries: 3, timeout: 30)
        gateway.authorize(token: load(:tok), scope: :refund)
      end
    end
  end
end
