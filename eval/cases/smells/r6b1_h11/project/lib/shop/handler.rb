module Shop
  class Handler
    def initialize(log)
      @log = log
    end

    def handle(error)
      @log.warn([error.message, error.hint].join(": "))
    end
  end
end
