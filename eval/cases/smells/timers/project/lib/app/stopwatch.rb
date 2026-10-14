module App
  class Stopwatch
    def initialize(runner)
      @runner = runner
    end

    def measure
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @runner.call
      Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    end

    def lap(clock)
      before = clock.now
      @runner.call
      clock.now - before
    end

    def wait(clock, timeout)
      deadline = clock.now + timeout
      @runner.call until clock.now > deadline
    end

    def label(order)
      "#{order.customer.address.city}, #{order.customer.address.zip} for #{@runner}"
    end
  end
end
