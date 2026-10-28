module Shop
  class Builder
    def initialize(mod)
      @mod = mod
    end

    def build
      @mod.class_eval <<~RUBY, __FILE__, __LINE__ + 1
        def name = "built"
      RUBY
      @mod.class_eval <<~RUBY, __FILE__, __LINE__ + 1
        def size = 1
      RUBY
      @mod
    end
  end
end
