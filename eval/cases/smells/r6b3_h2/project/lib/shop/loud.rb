require "forwardable"

module Shop
  module Loud
    extend Forwardable

    def_delegator :shout, :size, :volume

    def shout = "#{@text.upcase}!"
  end
end
