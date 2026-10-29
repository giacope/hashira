# frozen_string_literal: true

class Hashira::Complexity::Charges
  def self.none = new([], 0)

  def self.call = new([], 1)

  def self.mark(node, cost, label)
    new([Hashira::Complexity::Increment.new(node.location.start_line, cost, label)], 0)
  end

  def initialize(increments, calls)
    @increments = increments
    @calls = calls
  end

  def +(other) = Hashira::Complexity::Charges.new(@increments + other.increments, @calls + other.calls)

  def total = rows.sum { |_label, _line, cost| cost }

  def count = @calls

  def to_a = @increments

  def evidence
    labelled.map do |label, rows|
      lines = rows.map { |_label, line, _cost| line }.uniq
      "#{label} +#{rows.sum { |*, cost| cost }} (line#{"s" if lines.size > 1} #{lines.join(", ")})"
    end
  end

  def dominant = labelled.transform_values { |rows| rows.sum { |*, cost| cost } }.max_by(&:last).fetch(0)

  protected

  attr_reader :increments, :calls

  private

  def rows = @increments.map(&:to_a)

  def labelled = rows.group_by(&:first)
end
