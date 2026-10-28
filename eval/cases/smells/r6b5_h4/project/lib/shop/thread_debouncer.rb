module Shop
  class ThreadDebouncer
    class_attribute :debouncer_class, default: Shop::Debouncer

    def initialize(delay)
      @debouncer = debouncer_class.new(delay:)
    end

    def debounce(&) = @debouncer.debounce(&)
  end
end
