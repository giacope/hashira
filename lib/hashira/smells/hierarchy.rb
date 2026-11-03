# frozen_string_literal: true

require "prism"

class Hashira::Smells::Hierarchy
  Kin = Data.define(:parent, :foreign, :openings)

  ABSTRACT = /\AAbstract|Base\z/

  MARKS = %i[abstract_class= abstract_class primary_abstract_class abstract!].freeze

  NONE = Kin.new(parent: nil, foreign: false, openings: [])

  def initialize(
    types, builtins = Hashira::Runtime::Builtins.new, typeset = Hashira::Smells::Typeset.new(types),
    links = Hashira::Smells::Links.new(typeset, Hashira::Smells::Bodies.new)
  )
    @types = types
    @builtins = builtins
    @typeset = typeset
    @links = links
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

  def overrides(name, selector)
    found = [name]
    found.each { found.concat(children(it) - found) }
    found.drop(1).flat_map { definitions(it) }.select { it.accept(Hashira::Smells::Signature).name == selector }
  end

  def framed?(name) = [name, *ancestors(name)].any? { table.fetch(it, NONE).foreign }

  def root(name)
    framed = [name, *ancestors(name)].find { table.fetch(it, NONE).foreign }
    Hashira::Smells::Descent.new(table.fetch(framed, NONE).openings).parent.join("::")
  end

  def definitions(name) = table.fetch(name, NONE).openings.flat_map { it.reject { it.standing.singleton? } }

  def mixed(name) = table.fetch(name, NONE).openings.flat_map { @links.mixins(it) }.flat_map { definitions(it) }

  def abstract?(name)
    return true if ABSTRACT.match?(name.split("::").last)
    table.fetch(name, NONE).openings.any? do |type|
      type.any? { !it.standing.singleton? && it.accept(Hashira::Smells::Refusal).unimplemented? } || marked?(type)
    end
  end

  def built(name) = births.fetch(name, [])

  def home(name) = Hashira::Smells::Footprint.new(table.fetch(name).openings).site

  private

  def table
    @_table ||=
      @types.group_by(&:to_s).to_h do |name, openings|
        descent = Hashira::Smells::Descent.new(openings)
        parent = ancestor(name, descent.parent)
        [name, Kin.new(parent:, foreign: descent.parent? && !claimed.include?(parent), openings:)]
      end
  end

  def ancestor(name, segments)
    found = @typeset.resolve(name, segments).first
    found unless @builtins.core?(found)
  end

  def claimed = @_claimed ||= @types.select { it.seat.claimed? }.to_set(&:to_s)

  def marked?(type)
    type.accept(Hashira::Analysis::Syntax::Body).to_a.any? { it.is_a?(Prism::CallNode) && MARKS.include?(it.name) }
  end

  def births
    @_births ||=
      {}.tap do |found|
        @types.each do |type|
          type.accept(Hashira::Smells::News).each do |call, factory|
            next if relayed?(type, call, factory)
            (found[born(type, call)] ||= []) << type.seat.at(call.location.start_line)
          end
        end
      end
  end

  def relayed?(type, call, factory) = !call.receiver && factory.is_a?(Symbol) && !summoned?(type.to_s, factory)

  def summoned?(name, selector) = invocations.any? { |owner, call| call.name == selector && born(owner, call) == name }

  def invocations
    @_invocations ||=
      @types.flat_map do |type|
        type.accept(Hashira::Smells::Scope).sweep.grep(Prism::CallNode).select(&:receiver).map { [type, it] }
      end
  end

  def born(type, call)
    return type.to_s unless call.receiver
    @typeset.candidates(type.to_s, Hashira::Analysis::Syntax.new(call.receiver).segments).find { table.key?(it) }
  end
end
