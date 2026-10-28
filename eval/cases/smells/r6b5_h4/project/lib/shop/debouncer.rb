module Shop
  class Debouncer
    def initialize(delay:)
      @delay = delay
    end

    def debounce(&block)
      @task = Task.run(@delay, &block)
    end
  end
end
