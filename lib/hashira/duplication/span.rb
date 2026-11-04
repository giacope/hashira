# frozen_string_literal: true

class Hashira::Duplication::Span
  def initialize(file, line, finish)
    @file = file
    @line = line
    @finish = finish
  end

  def to_s = "#{@file}:#{@line}"

  def to_a = [@file, @line]

  def <=>(other) = to_a <=> other.to_a

  def range = "#{@file}:#{@line}-#{@finish}"

  def overlaps?(other) = @file == other.file && @line <= other.finish && other.line <= @finish

  def inside?(other) = @file == other.file && other.line <= @line && @finish <= other.finish

  protected

  attr_reader :file, :line, :finish
end
