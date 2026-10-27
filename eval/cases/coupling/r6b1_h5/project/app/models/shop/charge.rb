module Shop
  class Charge < Shop::ApplicationRecord
    def label = "Charge #{id}"
  end
end
