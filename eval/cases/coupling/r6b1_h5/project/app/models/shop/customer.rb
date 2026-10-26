module Shop
  class Customer < Shop::ApplicationRecord
    def label = "Customer #{id}"
  end
end
