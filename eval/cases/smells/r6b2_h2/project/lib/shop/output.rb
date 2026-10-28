# frozen_string_literal: true

module Shop
  class Output
    def initialize(io)
      @io = io
      @text = +""
    end

    def wait_for(pattern, timeout)
      deadline = Clock.monotonic + timeout
      while (now = Clock.monotonic) < deadline
        @text << @io.read_nonblock(512, exception: false).to_s
        return @text[pattern] if @text.match?(pattern)

        @io.wait_readable(deadline - now)
      end
    end

    def stamps = [Clock.monotonic, Clock.monotonic, @text.size]
  end
end
