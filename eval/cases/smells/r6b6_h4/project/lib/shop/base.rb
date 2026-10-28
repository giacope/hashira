require "forwardable"

module Shop
  class Base
    extend Forwardable

    def_delegators :@color, :colorize

    def initialize(color)
      @color = color
    end

    def show(text)
      "[#{colorize(text, :green)}]"
    end
  end
end
