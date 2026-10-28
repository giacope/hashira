module Shop
  class Plain < Base
    def colorize(obj, _color)
      obj.to_s
    end

    def shout(obj)
      obj.to_s.upcase
    end
  end
end
