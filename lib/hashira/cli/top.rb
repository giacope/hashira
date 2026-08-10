# frozen_string_literal: true

module Hashira::CLI::Top
  WHOLE = /\A[1-9]\d*\z/

  module_function

  def parse(value)
    return if value.empty?
    return Integer(value, 10) if value.match?(WHOLE)
    raise(Hashira::Error, "--top #{value.inspect} is not a positive whole number")
  end
end
