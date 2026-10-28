module Shop
  class Rescued
    def initialize(store)
      @store = store
    end

    def create(attrs)
      begin
        raise ArgumentError, "no gss for #{@store.name_of(attrs)}" if attrs.empty?
      rescue ArgumentError
        @store.warn(attrs)
      end
      @store.put(@store.name_of(attrs))
    end
  end
end
