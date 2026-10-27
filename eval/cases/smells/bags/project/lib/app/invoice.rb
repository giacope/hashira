module App
  Address = Struct.new(:street, :city, :zip)

  class Record < ActiveRecord::Base
    self.abstract_class = true
  end

  class Order < Record
    belongs_to :customer
  end

  class Invoice
    def initialize(order, address)
      @order = order
      @address = address
    end

    def total = (@order.quantity * @order.unit_cents) + @order.shipping_cents

    def label = "#{@address.street}, #{@address.zip} #{@address.city}"
  end
end
