module Shop
  module Mixin
    def indifferent? = true

    def merge_in(other)
      other.is_a?(::Hash) && other.respond_to?(:indifferent?) && other.indifferent?
    end

    def blend(other)
      other.is_a?(Hash) && other.respond_to?(:indifferent?) && other.indifferent?
    end
  end
end
