module Shop
  class Query
    def initialize(options)
      @json = options[:body]
      @fields = options[:fields]
      @json = nil if options[:plain]
      @fields = nil if options[:plain]
    end

    def response
      {
        json: !@json.nil?,
        size: 10,
        fields: @fields || []
      }
    end
  end
end
