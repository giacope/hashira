# frozen_string_literal: true

class Hashira::Complexity::Charges
  def self.none = new([], 0)

  def self.call = new([], 1)

  def self.mark(node, cost, label)
    new([Hashira::Complexity::Increment.new(line: node.location.start_line, cost:, label:)], 0)
  end

  def initialize(increments, calls)
    @increments = increments
    @calls = calls
  end

  def +(other) = Hashira::Complexity::Charges.new(@increments + other.increments, @calls + other.calls)

  def total = @increments.sum(&:cost)

  def count = @calls

  def to_a = @increments

  protected

  attr_reader :increments, :calls
end
