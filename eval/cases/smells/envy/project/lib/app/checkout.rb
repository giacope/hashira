module Shop
  class Cart
    attr_reader :items, :discount

    def initialize(items, discount)
      @items = items
      @discount = discount
    end
  end

  class Checkout
    def initialize(fee) = @fee = fee

    def total(cart)
      cart.items.sum(&:price) - cart.discount + (cart.items.size * @fee)
    end
  end
end
