module Shop
  class Query
    attr_reader :options

    def initialize(options)
      @options = options
    end

    def routing
      @routing = options[:routing] if options[:routing]
    end

    def scroll
      @scroll = @options[:scroll] if @options[:scroll]
    end

    def plain
      @plain = options if options
    end

    def local(opts)
      @local = opts[:local] if opts[:local]
    end

    def computed
      @computed = settings[:mode] if settings[:mode]
    end

    def settings = { mode: @options.fetch(:mode, :fast) }
  end
end
