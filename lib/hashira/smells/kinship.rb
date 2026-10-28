# frozen_string_literal: true

require "prism"

class Hashira::Smells::Kinship
  READERS = Hashira::Smells::Attributes::READERS

  def initialize(types, lineage)
    @types = types
    @lineage = lineage
  end

  def protocol(type)
    name = type.name
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
    @_letters ||= @types.flat_map { @lineage.messages(it) }.group_by(&:last).transform_values { it.to_set(&:first) }
  end

  def kindred(name)
    rivals = @_rivals ||= Hashira::Smells::Rivals.new(@types, @lineage)
    kin = reach(name, ancestry) + reach(name, descent) + rivals.of(name) + rivals.sides(name)
    kin.map { words(it) }.reduce(Set.new, :|) + peers(name)
  end

  def index = @_index ||= @types.group_by(&:name)

  def ancestry = @_ancestry ||= index.transform_values { |kin| kin.flat_map { @lineage.pointed(it) }.compact.uniq }

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
      index.keys.group_by { brood(it) }.except(nil).transform_values { |names| names.flat_map { words(it).to_a }.tally }
    @_broods.fetch(brood(name), {}).select { |_, count| count > 1 }.keys.to_set
  end

  def brood(name)
    node = index.fetch(name).filter_map(&:parent).first
    @lineage.resolve(name, Hashira::Analysis::Syntax.new(node).segments) || node.slice.delete_prefix("::") if node
  end

  def words(name) = said[name]

  def adopted?(name) = [name, *reach(name, ancestry)].any? { foreign?(it) }

  def foreign?(name) = index.fetch(name).any? { @lineage.pointed(it).include?(nil) }

  def heritage(name)
    parents = [name, *reach(name, ancestry)].flat_map { index.fetch(it) }.flat_map { @lineage.abroad(it) }
    parents.reduce(Set.new) { |all, parent| all | Hashira::Analysis::INHERITED.fetch(parent, Set.new) }
  end

  def said = @_said ||= Hash.new { |memo, name| memo[name] = defined(name) }

  def defined(name) = index.fetch(name).flat_map { carried(it) }.flat_map { named(it) }.to_set

  def named(type) = @lineage.definitions(type).map(&:name) + declared(@lineage.sweep(type))

  def declared(swept)
    attributes = Hashira::Smells::Attributes.new(swept)
    forwards = Hashira::Smells::Forwards.new(swept, Hashira::Smells::Bonds.new(swept), Set.new)
    attributes.declared(READERS).map(&:to_sym) + attributes.writers + forwards.names.to_a
  end

  def carried(type) = [type, *@lineage.mixins(type).flat_map { index.fetch(it) }]
end
