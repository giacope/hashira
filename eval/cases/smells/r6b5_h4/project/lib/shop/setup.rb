module Shop
  module Setup
    def self.testing! = Shop::ThreadDebouncer.debouncer_class = Shop::ImmediateDebouncer
  end
end
