# frozen_string_literal: true

class Evaluation::Check
  def self.of(suite, name, expected, actual) = new(suite, name, expected, actual)

  def initialize(suite, name, expected, actual)
    @suite = suite
    @name = name
    @expected = expected
    @actual = actual
  end

  def entry = [@suite, to_h]

  def to_h = { "name" => @name, "passed" => @expected == @actual, "expected" => @expected, "actual" => @actual }
end
