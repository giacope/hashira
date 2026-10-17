module App
  class Options
    attr_accessor :timeout, :retries
    attr_writer :verbose

    def initialize(timeout, retries)
      @timeout = timeout
      @retries = retries
    end

    def verbose? = @verbose
  end

  class Client
    def get(options) = options.retries.times.map { options.timeout * 2 }
  end

  Size = Data.define(:width, :height)

  class ApiError < StandardError
    attr_reader :code, :body

    def initialize(code, body)
      @code = code
      @body = body
      super("api failed")
    end
  end

  class Range
    attr_reader :low, :high

    def initialize(low, high)
      @low = low
      @high = high
    end

    def cover?(value) = value.between?(low, high)
  end
end
