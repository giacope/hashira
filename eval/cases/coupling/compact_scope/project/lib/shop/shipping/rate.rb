class Shop::Shipping::Rate
  def bill = Billing::Invoice.new(self)
end
