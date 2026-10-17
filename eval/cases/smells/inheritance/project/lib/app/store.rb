module App
  class Store
    def initialize
      @rows = {}
    end

    def read(key) = @rows[key]

    def write(key, value)
      @rows[key] = value
    end

    def delete(key)
      @rows.delete(key)
    end

    def changed(key); end
  end

  class ReadOnlyStore < Store
    def write(_key, _value)
      raise NotImplementedError, "read only"
    end

    def delete(_key) = raise(NotImplementedError, "read only")
  end

  class Mirror < Store
    def changed(key) = puts("changed #{key}")

    def write(key, value)
      super
      changed(key)
    end
  end
end
