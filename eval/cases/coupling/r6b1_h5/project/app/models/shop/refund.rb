module Shop
  class Refund < Shop::ApplicationRecord
    def label = "Refund #{id}"
  end
end
