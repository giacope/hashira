module Shop
  class Query
    def initialize(options)
      @options = options
    end

    private

    attr_reader :options
  end

  class AnyQuery < Query
    def conditions(scope)
      scope = scope.where(context: options[:on]) if options[:on]
      scope
    end
  end
end
