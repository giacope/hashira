module App
  class Record < ActiveRecord::Base
    self.abstract_class = true
  end

  class Charge < Record
    def sync! = update!(synced_at: Time.current)
  end

  class StripeCharge < Charge
    def sync! = update!(amount: remote_amount)
  end

  class GiftCharge < Charge
    def gift? = true
  end

  class LineItems < Array
    def total = sum(&:price)
  end
end
