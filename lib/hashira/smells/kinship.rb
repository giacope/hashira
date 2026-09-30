# frozen_string_literal: true

require "prism"

class Hashira::Smells::Kinship
  def initialize(types, lineage)
    @types = types
    @lineage = lineage
  end

  def protocol(type) = shared[type.name]

  private

  def kindred(name) = spoken(reach(name, ancestry) + reach(name, descent)) + peers(name)

  def index = @_index ||= @types.group_by(&:name)

  def ancestry = @_ancestry ||= index.transform_values { |kin| kin.flat_map { @lineage.pointed(it) }.compact.uniq }

  def descent = @_descent ||= links.group_by(&:first).transform_values { it.map(&:last) }

  def links = ancestry.flat_map { |child, parents| parents.map { [it, child] } }

  def reach(name, edges)
    found = Set[name]
    frontier = [name]
    frontier = step(frontier, edges, found) until frontier.empty?
    found.delete(name)
  end

  def step(frontier, edges, found)
    frontier.flat_map { edges.fetch(it, []) }.uniq.reject { found.include?(it) }.each { found << it }
  end

  def peers(name) = broods.fetch(brood(name), {}).select { |_, count| count > 1 }.keys.to_set

  def broods = @_broods ||= index.keys.group_by { brood(it) }.except(nil).transform_values { |names| tally(names) }

  def tally(names) = names.flat_map { words(it).to_a }.tally

  def brood(name)
    segments = index.fetch(name).map(&:superclass).find(&:any?)
    @lineage.resolve(name, segments) || segments.join("::") if segments
  end

  def spoken(names) = names.map { words(it) }.reduce(Set.new, :|)

  def words(name) = said[name]

  def defined(type) = Hashira::Smells::Scope.sweep(type.node).grep(Prism::DefNode).reject(&:receiver).map(&:name)

  def shared = @_shared ||= Hash.new { |memo, name| memo[name] = words(name) & kindred(name) }

  def said = @_said ||= Hash.new { |memo, name| memo[name] = index.fetch(name).flat_map { defined(it) }.to_set }
end
