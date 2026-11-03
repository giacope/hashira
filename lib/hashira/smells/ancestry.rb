# frozen_string_literal: true

require "prism"

class Hashira::Smells::Ancestry
  MIXINS = %i[include prepend].freeze

  def initialize(walk, ownership)
    @walk = walk
    @ownership = ownership
  end

  def up(name) = climb(name, upward)

  def down(name) = climb(name, downward)

  def openings(name) = opened.fetch(name, [])

  def owner(name, selector) = up(name).lazy.select { |type| openings(type).any? { defines?(it, selector) } }.first(1)

  private

  def defines?(node, selector)
    Hashira::Analysis::TypeWalk.new(node).sections.any? do |definition, section|
      definition.name == selector && !definition.receiver && section != :singleton
    end
  end

  def climb(name, edges)
    found = [name]
    found.each { found.concat(edges.fetch(it, []) - found) }
  end

  def upward = @_upward ||= ties.group_by(&:first).transform_values { it.map(&:last) }

  def downward = @_downward ||= ties.group_by(&:last).transform_values { it.map(&:first) }

  def opened = @_opened ||= @walk.to_a.group_by { |_node, full| full.join("::") }.transform_values { it.map(&:first) }

  def ties
    @_ties ||=
      @walk.to_a.flat_map do |node, full|
        owner = full.join("::")
        above(node).flat_map { |parent| @ownership.placed(parent, owner).map { [owner, it] } }
      end
  end

  def above(node)
    calls = Hashira::Smells::Scope.new(node).sweep.grep(Prism::CallNode)
    mixed = calls.select { Hashira::Analysis::Syntax::Call.new(it).macro?(MIXINS) }.flat_map { it.arguments.arguments }
    [*(node.superclass if node.is_a?(Prism::ClassNode)), *mixed]
  end
end
