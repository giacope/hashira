module Shop
  class Stamp
    def initialize(mod)
      @mod = mod
    end

    def label = "#{@mod.name.downcase}:#{__LINE__ + 1}:#{@mod.name.downcase}"
  end
end
