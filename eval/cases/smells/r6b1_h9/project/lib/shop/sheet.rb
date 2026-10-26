module Shop
  class Sheet
    def name=(value)
      @name = value
    end

    def email=(value)
      @email = value
    end

    def team=(value)
      @team = value
    end

    def summary = [@name, @email, @team].join(" ")
  end
end
