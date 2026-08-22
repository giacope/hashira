# frozen_string_literal: true

require "prism"

class Hashira::Smells::Gated::Family
  READERS = %i[attr_reader attr_accessor attr_writer attr].freeze

  ALIASES = %i[alias_method].freeze

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

  private

  def lineage = @_lineage ||= Hashira::Smells::Lineage.new(@types)

  def charts = @_charts ||= @types.to_h { [it.name, lineage.ancestry(it) || []] }

  def brood = @_brood ||= @types.each_with_object({}) { |type, found| adopt(found, type.name, type) }

  def adopt(found, home, type)
    charts.fetch(home).map(&:name).uniq.each { (found[it] ||= []) << type unless it == home }
  end

  def tables = @_tables ||= {}.compare_by_identity

  def chart(type) = tables[type.node] = type.defs.reject(&:singleton?).map { it.node.name } + granted(type)

  def granted(type) = named(passed(type, READERS) + passed(type, ALIASES) + renamed(type))

  def renamed(type) = swept(type).grep(Prism::AliasMethodNode).map(&:new_name)

  def passed(type, names)
    swept(type).grep(Prism::CallNode).select { calls?(it, names) }.flat_map { it.arguments.arguments }
  end

  def calls?(node, names) = names.include?(node.name) && !node.receiver && node.arguments

  def named(nodes) = nodes.grep(Prism::SymbolNode).map { it.unescaped.to_sym }

  def swept(type) = Hashira::Smells::Scope.sweep(type.node)
end
