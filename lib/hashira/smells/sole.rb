# frozen_string_literal: true

class Hashira::Smells::Sole
  def initialize(found)
    @found = found
  end

  def to_a = @found.any? && @found.uniq.one? ? @found.first(1) : []
end
