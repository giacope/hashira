# frozen_string_literal: true

require "prism"

class Hashira::Smells::Ancestry
  MIXINS = %i[include prepend].freeze

  def initialize(walked, ownership)
    @walked = walked
    @ownership = ownership
  end

  def up(name) = climb(name, upward)

  def down(name) = climb(name, downward)

  def openings(name) = opened.fetch(name, [])

  private

  def climb(name, edges)
    found = [name]
    found.each { found.concat(edges.fetch(it, []) - found) }
  end

  def upward = @_upward ||= ties.group_by(&:first).transform_values { it.map(&:last) }

  def downward = @_downward ||= ties.group_by(&:last).transform_values { it.map(&:first) }

  def opened = @_opened ||= @walked.group_by { |_node, full| full.join("::") }.transform_values { it.map(&:first) }

  def ties
    @_ties ||= @walked.flat_map do |node, full|
      owner = full.join("::")
      above(node).map { [owner, @ownership.placed(it, owner)] }
    end.select(&:last)
  end

  def above(node)
    calls = Hashira::Smells::Scope.new(node).sweep.grep(Prism::CallNode)
    mixed = calls.select { Hashira::Analysis::Syntax.new(it).macro?(MIXINS) }.flat_map { it.arguments.arguments }
    [*(node.superclass if node.is_a?(Prism::ClassNode)), *mixed]
  end
end
