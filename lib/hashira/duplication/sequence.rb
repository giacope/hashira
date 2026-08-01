# frozen_string_literal: true

class Hashira::Duplication::Sequence
  MIN_STATEMENTS = 1
  MAX_STATEMENTS = 12
  LIST_RUN = 3

  def initialize(file, statements)
    @file = file
    @statements = statements
  end

  def fragments = segments.flat_map { windows(it) }

  private

  def segments = runs.chunk { listing?(it) }.filter_map { |listed, group| group.flatten(1) unless listed }

  def listing?(run) = run.size >= LIST_RUN

  def runs = shaped.slice_when { |left, right| left.last != right.last }.map { it.map(&:first) }

  def shaped = @statements.map { [it, fragment([it]).types] }

  def windows(segment) = lengths(segment).flat_map { |length| slide(segment, length) }

  def lengths(segment) = MIN_STATEMENTS..[segment.size, MAX_STATEMENTS].min

  def slide(segment, length) = (0..(segment.size - length)).map { fragment(segment[it, length]) }

  def fragment(roots) = Hashira::Duplication::Fragment.new(@file, roots)
end
