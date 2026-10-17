module App
  class Checkout
    def initialize(mailer)
      @items = []
      @discount = 0
      @mailer = mailer
      @sent = []
    end

    def add(item) = @items << item

    def discount!(amount)
      @discount = amount
    end

    def total = @items.sum(&:price) - @discount

    def receipt(address)
      @mailer.deliver(to: address, body: "thanks")
      @sent << address
    end

    def resend = @sent.each { |address| @mailer.deliver(to: address, body: "again") }

    def sent? = @sent.any?
  end
end
