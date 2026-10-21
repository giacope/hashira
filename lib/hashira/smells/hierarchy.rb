# frozen_string_literal: true

require "prism"

class Hashira::Smells::Hierarchy
  Kin = Data.define(:parent, :foreign, :openings)

  FENCES = [Prism::ClassNode, Prism::ModuleNode].freeze

  ABSTRACT = /\AAbstract|Base\z/

  MARKS = %i[abstract_class= abstract_class primary_abstract_class abstract!].freeze

  NONE = Kin.new(parent: nil, foreign: false, openings: [])

  def initialize(types)
    @types = types
  end

  def parent(name) = table.fetch(name, NONE).parent

  def ancestors(name)
    found = [name]
    while (above = table.fetch(found.last, NONE).parent) && !found.include?(above)
      found << above
    end
    found.drop(1)
  end

  def children(name) = table.filter_map { |child, kin| child if kin.parent == name }

  def framed?(name) = [name, *ancestors(name)].any? { table.fetch(it, NONE).foreign }

  def definitions(name) = table.fetch(name, NONE).openings.flat_map(&:owned)

  def mixed(name) = table.fetch(name, NONE).openings.flat_map { lineage.mixins(it) }.flat_map { definitions(it) }

  def abstract?(name)
    return true if ABSTRACT.match?(name.split("::").last)
    table.fetch(name, NONE).openings.any? do |type|
      type.owned.any? { Hashira::Smells::Refusal.unimplemented?(it.node) } || marked?(type)
    end
  end

  def built(name) = births.fetch(name, [])

  private

  def table
    @_table ||=
      @types.group_by(&:name).to_h do |name, openings|
        node = openings.filter_map { it.node.superclass if it.kind == :class }.first
        parent = ancestor(name, node)
        [name, Kin.new(parent:, foreign: !node.nil? && !parent, openings:)]
      end
  end

  def ancestor(name, node)
    found = lineage.resolve(name, Hashira::Analysis::Syntax.segments(node))
    found unless Hashira::Analysis::CORE.include?(found)
  end

  def lineage = @_lineage ||= Hashira::Smells::Lineage.new(@types)

  def marked?(type)
    Hashira::Analysis::Syntax.statements(type.node).any? { it.is_a?(Prism::CallNode) && MARKS.include?(it.name) }
  end

  def births
    @_births ||=
      {}.tap do |found|
        @types.each do |type|
          news(type.node).each do |call, factory|
            next if relayed?(type, call, factory)
            (found[born(type, call)] ||= []) << "#{type.file}:#{call.location.start_line}"
          end
        end
      end
  end

  def news(node, factory = nil, found = [])
    node.compact_child_nodes.each do |child|
      next if FENCES.include?(child.class)
      found << [child, factory] if child.is_a?(Prism::CallNode) && child.name == :new
      news(child, child.is_a?(Prism::DefNode) ? child.name : factory, found)
    end
    found
  end

  def relayed?(type, call, factory) = !call.receiver && factory.is_a?(Symbol) && !summoned?(type.name, factory)

  def summoned?(name, selector) = invocations.any? { |owner, call| call.name == selector && born(owner, call) == name }

  def invocations
    @_invocations ||=
      @types.flat_map do |type|
        Hashira::Smells::Scope.sweep(type.node).grep(Prism::CallNode).select(&:receiver).map { [type, it] }
      end
  end

  def born(type, call)
    return type.name unless call.receiver
    segments = Hashira::Analysis::Syntax.segments(call.receiver)
    parts = type.name.split("::")
    parts.size.downto(0).map { (parts.first(it) + segments).join("::") }.find { table.key?(it) } unless segments.empty?
  end
end
