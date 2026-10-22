# frozen_string_literal: true

class Hashira::CLI::Top
  WHOLE = /\A[1-9]\d*\z/

  def initialize(flag)
    @flag = flag
  end

  def parse(value)
    return if value.empty?
    return Integer(value, 10) if value.match?(WHOLE)
    raise(Hashira::Error, "#{@flag} #{value.inspect} is not a positive whole number")
  end
end
