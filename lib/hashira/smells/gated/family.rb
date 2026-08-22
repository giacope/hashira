# frozen_string_literal: true

require "prism"

class Hashira::Smells::Gated::Family
  READERS = %i[attr_reader attr_accessor attr_writer attr].freeze

  ALIASES = %i[alias_method].freeze

  MIXINS = %i[include].freeze

  def initialize(types)
    @types = types
  end

  attr_reader :types

  def visible?(type) = !ancestry(type).empty?

  def ancestry(type) = charts.fetch(type.name)

  def descendants(type) = brood.fetch(type.name, [])

  def kin(type) = ancestry(type) + descendants(type)

  def answers?(type, name) = kin(type).any? { names(it).include?(name) }

  def names(type) = tables.fetch(type.node) { chart(type) }

  def elders(type) = ancestry(type).reject { it.name == type.name }

  def leaf?(type) = type.kind == :class && descendants(type).empty?

  def ancestral(type, name) = elders(type).flat_map(&:owned).select { it.node.name == name }

  def reach(type) = kin(type).flat_map { Hashira::Smells::Scope.sweep(it.node) }

  def mixins(type) = included(type).map { kinfolk(type, it) }.reject(&:empty?)

  def sole(segments) = only(@types.select { tail?(it.name, segments.join("::")) }.uniq(&:name))

  def related?(type, other) = bloodline(type).intersect?(bloodline(other))

  def bloodline(type) = trail(type.name, [])

  private

  def included(type)
    passed(type, MIXINS).map { Hashira::Analysis::Syntax.segments(it) }.reject(&:empty?)
  end

  def kinfolk(type, segments) = ancestry(type).select { same?(it, segments) }

  def only(found) = (found.first if found.one?)

  def trail(name, known)
    return known if known.include?(name)
    parent = @types.select { it.name == name }.filter_map { above(it) }.first
    parent ? trail(parent, known + [name]) : known + [name]
  end

  def above(type) = sole(Hashira::Analysis::Syntax.segments(type.parent))&.name

  def same?(kin, segments) = tail?(kin.name, segments.join("::"))

  def tail?(name, path) = name == path || name.end_with?("::#{path}")

  def lineage = @_lineage ||= Hashira::Smells::Lineage.new(@types)

  def charts = @_charts ||= @types.to_h { [it.name, lineage.ancestry(it) || []] }

  def brood = @_brood ||= @types.each_with_object({}) { |type, found| adopt(found, type.name, type) }

  def adopt(found, home, type)
    charts.fetch(home).map(&:name).uniq.each { (found[it] ||= []) << type unless it == home }
  end

  def tables = @_tables ||= {}.compare_by_identity

  def chart(type) = tables[type.node] = type.owned.map { it.node.name } + granted(type)

  def granted(type) = named(passed(type, READERS) + passed(type, ALIASES) + renamed(type))

  def renamed(type) = swept(type).grep(Prism::AliasMethodNode).map(&:new_name)

  def passed(type, names)
    swept(type).grep(Prism::CallNode).select { calls?(it, names) }.flat_map { it.arguments.arguments }
  end

  def calls?(node, names) = names.include?(node.name) && !node.receiver && node.arguments

  def named(nodes) = nodes.grep(Prism::SymbolNode).map { it.unescaped.to_sym }

  def swept(type) = Hashira::Smells::Scope.sweep(type.node)
end
