# frozen_string_literal: true

require "prism"

class Hashira::Smells::Gated::Family
  RUBY = (Object.instance_methods + Object.private_instance_methods).to_set.freeze

  MACROS = %i[
    attr attr_reader attr_writer attr_accessor include extend prepend private public protected
    module_function alias_method require require_relative raise freeze private_constant public_constant
  ].to_set.freeze

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

  def lone(segments) = only(@types.select { tail?(it.name, segments.join("::")) }.uniq(&:name))

  def related?(type, other) = bloodline(type).intersect?(bloodline(other))

  def bloodline(type) = ascent(type).select { born?(it) }

  def ascent(type) = climb(type.name, [])

  def kindred?(name, path) = tail?(name, path)

  def whole?(type) = plain?(type) && kin(type).all? { answered?(type, it) }

  private

  def included(type)
    passed(type, MIXINS).map { Hashira::Analysis::Syntax.segments(it) }.reject(&:empty?)
  end

  def kinfolk(type, segments) = ancestry(type).select { same?(it, segments) }

  def only(found) = (found.first if found.one?)

  def born?(name) = @types.any? { it.name == name }

  def climb(name, known)
    return known if seen?(known, name)
    written = @types.select { it.name == name }.map(&:parent).reject(&:empty?).first
    written ? beyond(written, known + [name]) : known + [name]
  end

  def beyond(written, known)
    above = lone(written)
    above ? climb(above.name, known) : known + [written.join("::")]
  end

  def seen?(known, name) = known.include?(name)

  def plain?(type) = kin(type).all? { tame?(it) }

  def tame?(kin)
    Hashira::Analysis::Syntax.statements(kin.node).compact.grep(Prism::CallNode).all? { MACROS.include?(it.name) }
  end

  def answered?(type, kin)
    kin.owned.flat_map { inward(it) }.all? { RUBY.include?(it) || answers?(type, it) }
  end

  def inward(method)
    Hashira::Smells::Scope.inside(method.node).grep(Prism::CallNode).select { self?(it) }.map(&:name)
  end

  def self?(node) = spoken?(node.receiver) && !passing?(node.block)

  def passing?(block) = block.is_a?(Prism::BlockArgumentNode)

  def spoken?(receiver) = !receiver || receiver.is_a?(Prism::SelfNode)

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
