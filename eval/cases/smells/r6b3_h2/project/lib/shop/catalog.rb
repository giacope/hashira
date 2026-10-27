module Shop
  class Catalog
    include Registry
    include Loud

    def initialize(text)
      @text = text
    end
  end
end
