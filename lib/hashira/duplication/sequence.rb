# frozen_string_literal: true

require "prism"

class Hashira::Duplication::Sequence
  MIN_STATEMENTS = 1
  MAX_STATEMENTS = 12
  LIST_RUN = 3
  SCOPES = [Prism::ClassNode, Prism::ModuleNode, Prism::SingletonClassNode].freeze

  def initialize(file, statements, walks)
    @file = file
    @statements = statements
    @walks = walks
  end

  def fragments = segments.flat_map { windows(it) }

  def unlisted = segments.flatten(1)

  private

  def segments = runs.chunk { skipped?(it) }.filter_map { |skip, group| group.flatten(1) unless skip }

  def skipped?(run) = run.size >= LIST_RUN || SCOPES.include?(run.first.class)

  def runs = shaped.slice_when { |left, right| left.last != right.last }.map { it.map(&:first) }

  def shaped = @statements.map { [it, fragment([it]).types] }

  def windows(segment) = lengths(segment).flat_map { |length| slide(segment, length) }

  def lengths(segment) = MIN_STATEMENTS..[segment.size, MAX_STATEMENTS].min

  def slide(segment, length) = spans(segment, length).map { fragment(segment[it, length]) }.reject(&:sectioned?)

  def spans(segment, length) = 0..(segment.size - length)

  def fragment(roots) = Hashira::Duplication::Fragment.new(@file, roots, @walks)
end
