module Shop
  class Shape
    def initialize(side)
      @side = side
    end

    def describe
      "#{name} of #{area}"
    end

    def area
      raise NoMethodError
    end

    def name = "shape"
  end
end
