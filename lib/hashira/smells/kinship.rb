# frozen_string_literal: true

require "prism"

class Hashira::Smells::Kinship
  BUILTINS = Hashira::Runtime::Builtins.new

  private_constant :BUILTINS

  def initialize(
    types, typeset, links = Hashira::Smells::Links.new(typeset),
    rivals = Hashira::Smells::Rivals.new(types, typeset)
  )
    @types = types
    @typeset = typeset
    @links = links
    @rivals = rivals
  end

  def protocol(type)
    name = type.to_s
    spoken = words(name)
    hooks = adopted?(name) ? spoken - (told(name) - heritage(name)) : Set.new
    (spoken & kindred(name)) | hooks
  end

  private

  def told(name)
    kin = [nil, name, *reach(name, ancestry), *reach(name, descent)]
    kin.map { letters.fetch(it, Set.new) }.reduce(:|)
  end

  def letters
    @_letters ||= @types.flat_map { @links.messages(it) }.group_by(&:last).transform_values { it.to_set(&:first) }
  end

  def kindred(name)
    kin = reach(name, ancestry) + reach(name, descent) + @rivals.of(name) + @rivals.sides(name)
    kin.map { words(it) }.reduce(Set.new, :|) + peers(name)
  end

  def index = @_index ||= @types.group_by(&:to_s)

  def ancestry = @_ancestry ||= index.transform_values { |kin| kin.flat_map { @links.pointed(it) }.uniq }

  def descent
    @_descent ||=
      ancestry.flat_map { |child, parents| parents.map { [it, child] } }.group_by(&:first)
        .transform_values { it.map(&:last) }
  end

  def reach(name, edges)
    found = Set[name]
    frontier = [name]
    until frontier.empty?
      frontier = frontier.flat_map { edges.fetch(it, []) }.uniq.reject { found.include?(it) }
      found.merge(frontier)
    end
    found.delete(name)
  end

  def peers(name)
    @_broods ||=
      index.keys.group_by { brood(it) }.except([]).transform_values { |names| names.flat_map { words(it).to_a }.tally }
    @_broods.fetch(brood(name), {}).select { |_, count| count > 1 }.keys.to_set
  end

  def brood(name)
    heading = index.fetch(name).map { it.accept(Hashira::Smells::Heading) }.find { !it.written.empty? }
    heading ? [@typeset.resolve(name, heading.parent).fetch(0, heading.written)] : []
  end

  def words(name) = said[name] ||= defined(name)

  def adopted?(name) = [name, *reach(name, ancestry)].any? { foreign?(it) }

  def foreign?(name) = index.fetch(name).any? { @links.abroad(it).any? }

  def heritage(name)
    parents = [name, *reach(name, ancestry)].flat_map { index.fetch(it) }.flat_map { @links.abroad(it) }
    parents.reduce(Set.new) { |all, parent| all | BUILTINS.heritage(parent) }
  end

  def said = @_said ||= {}

  def defined(name) = index.fetch(name).flat_map { carried(it) }.flat_map { named(it) }.to_set

  def named(type)
    swept = @typeset.sweep(type)
    swept.grep(Prism::DefNode).reject(&:receiver).map(&:name) + declared(swept)
  end

  def declared(swept)
    attributes = Hashira::Smells::Attributes.new(swept)
    forwards = Hashira::Smells::Forwards.new(swept)
    attributes.readers.map(&:to_sym) + attributes.writers + forwards.names.to_a
  end

  def carried(type) = [type, *@links.mixins(type).flat_map { index.fetch(it) }]
end
