module App
  module Orders
    class Checkout
      def run(gateway)
        gateway.configure(fetch(:host), fetch(:port))
        gateway.connect(retries: 3, timeout: 30)
        gateway.authorize(token: load(:tok), scope: :sale)
      end
    end
  end
end
