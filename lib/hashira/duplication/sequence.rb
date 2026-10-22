# frozen_string_literal: true

require "prism"

class Hashira::Duplication::Sequence
  MIN_STATEMENTS = 1
  MAX_STATEMENTS = 12
  LIST_RUN = 3
  SCOPES = [Prism::ClassNode, Prism::ModuleNode, Prism::SingletonClassNode].freeze
  TABLES = [Prism::ArrayNode, Prism::HashNode, Prism::KeywordHashNode].freeze

  def initialize(file, statements, walks, setting)
    @file = file
    @statements = statements
    @walks = walks
    @setting = setting
  end

  def fragments = segments.flat_map { windows(it) }

  def unlisted = segments.flatten(1)

  private

  def segments = runs.chunk { skipped?(it) }.filter_map { |skip, group| group.flatten(1) unless skip }

  def skipped?(run) = run.size >= LIST_RUN || SCOPES.include?(run.first.class)

  def runs = shaped.slice_when { |left, right| left.last != right.last }.map { it.map(&:first) }

  def shaped = @statements.map { [it, outline(it)] }

  def outline(node) = [node.type] + (table?(node) ? [] : node.compact_child_nodes.flat_map { outline(it) })

  def table?(node) = TABLES.include?(node.class) && Hashira::Duplication::Literal.new(node).literal?

  def windows(segment) = (MIN_STATEMENTS..[segment.size, MAX_STATEMENTS].min).flat_map { slide(segment, it) }

  def slide(segment, length) = (0..(segment.size - length)).map { fragment(segment[it, length]) }.reject(&:sectioned?)

  def fragment(roots) = Hashira::Duplication::Fragment.new(@file, roots, @walks, @setting)
end
