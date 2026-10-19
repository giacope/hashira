module App
  class Jobs
    def pay(id)
      transaction do
        order = load(:order, id)
        order.check(:stock, limit: 5, warn: true)
        order.save(:paid, status: "ok", at: clock.now)
      end
    end

    def ship(id)
      transaction do
        order = load(:order, id)
        order.check(:stock, limit: 5, warn: true)
        order.save(:shipped, status: "ok", at: clock.now)
      end
    end

    private

    def transaction = yield
  end
end
