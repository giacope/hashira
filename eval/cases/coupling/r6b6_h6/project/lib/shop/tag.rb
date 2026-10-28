module Shop
  class Tag
    def initialize(name)
      @name = name
    end

    def save(names)
      raise Shop::DuplicateError if names.include?(@name)
      names + [@name]
    end
  end
end
