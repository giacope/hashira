# frozen_string_literal: true

module Shop
  class Nothing
    def eql?(other) = other.is_a?(Nothing)

    alias_method :==, :eql?

    def hash = Nothing.name.hash

    def <=>(other) = other.is_a?(Nothing) ? 0 : -1

    def inspect = "Nothing".dup.freeze

    def label = "Nothing".upcase
  end
end
