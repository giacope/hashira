module Shop
  class Dash
    def initialize(values)
      @values = values
    end

    def assign(property, value)
      _assert_property_required!(property, value)
      _assert_property_known!(property, value)
      @values[property] = value
    end

    private

    def _assert_property_required!(property, value)
      _fail_property_required_error!(property) if value.nil? && _required?(property)
    end

    def _assert_property_known!(property, value)
      _warn_property_missing(property) if value.nil?
    end

    def _fail_property_required_error!(property)
      message = "is required"
      raise ArgumentError, "the property `#{property}` " + message
    end

    def _warn_property_missing(property)
      @log.warn(property)
    end

    def _required?(property)
      property != :id
    end
  end
end
