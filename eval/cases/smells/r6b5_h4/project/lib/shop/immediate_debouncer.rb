module Shop
  class ImmediateDebouncer
    def initialize(delay:); end

    def debounce(&block)
      block.call
    end
  end
end
