# frozen_string_literal: true

require "prism"

class Hashira::Coupling::Folding
  SUFFIXES = %w[Resource Serializer Policy Decorator].freeze

  def initialize(definitions, census, suffixes: [])
    @definitions = definitions
    @census = census
    @suffixes = suffixes
  end

  def map = @_map ||= links.keys.to_h { [it, settle(it, links)] }.reject { |from, to| from == to }

  def disclosed
    map.map { |from, to| { from:, to:, via: parents.key?(from) ? "base" : "suffix" } }
  end

  private

  def links = @_links ||= named.merge(parents)

  def parents
    @_parents ||= singles.select { |_name, one| one.superclass }.to_h { |name, one| [name, target(one)] }.compact
  end

  def named
    singles.keys.filter_map { |name| pair(name, crop(name)) }.to_h
  end

  def pair(name, stem) = ([name, stem] if stem && @census.packages.include?(stem))

  def crop(name)
    suffix = @suffixes.find { trims?(name, it) }
    suffix && name.delete_suffix(suffix)
  end

  def trims?(name, suffix) = name.end_with?(suffix) && name != suffix

  def singles = @_singles ||= lone.group_by(&:name).transform_values { it.find(&:superclass) || it.last }

  def lone = @definitions.select(&:singular?).reject { anchored.include?(it.name) }

  def anchored = @_anchored ||= @definitions.select(&:nested?).to_set(&:name)

  def target(one) = @census.pinpoint(Hashira::Analysis::Syntax.segments(one.superclass))

  def settle(name, links)
    trail = [name]
    while (target = links[name]) && !trail.include?(target)
      trail << (name = target)
    end
    target ? trail.drop(trail.index(target)).min : name
  end
end
