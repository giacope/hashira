# frozen_string_literal: true

require "prism"

class Hashira::Coupling::Folding
  SUFFIXES = %w[Resource Serializer Policy Decorator].freeze

  MIXINS = %i[extend include].freeze

  KINDS = %w[base mixin suffix plural].freeze

  def initialize(definitions, census, suffixes: [])
    @definitions = definitions
    @census = census
    @suffixes = suffixes
  end

  def map = @_map ||= links.keys.to_h { [it, settle(it, links)] }.reject { |from, to| from == to }

  def disclosed
    map.map { |from, to| { from:, to:, via: KINDS[kinds.index { it.key?(from) }] } }
  end

  private

  def kinds = @_kinds ||= [parents, mixins, named, plurals]

  def links = @_links ||= kinds.reverse.reduce(:merge)

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

  def plurals = known.flat_map { |stem| forms(stem).map { [it, stem] } }.select { known.include?(it.first) }.to_h

  def forms(stem) = ["#{stem}s", "#{stem}es", "#{stem.delete_suffix("y")}ies"]

  def known = @_known ||= @census.packages.to_set

  def mixins = badges.transform_values { adopted(it) }.compact

  def badges = lone.group_by(&:name).select { |_name, ones| ones.all? { badge?(it) } }.transform_values(&:first)

  def badge?(definition) = definition.module? && syntax.statements(definition.node).all? { syntax.macro?(it, MIXINS) }

  def adopted(badge) = adoptions(badge).lazy.filter_map { @census.pinpoint(syntax.segments(it)) }.first

  def adoptions(badge) = syntax.statements(badge.node).flat_map { it.arguments.arguments }

  def singles
    @_singles ||= lone.select(&:klass?).group_by(&:name).transform_values { it.find(&:superclass) || it.last }
  end

  def lone = @_lone ||= @definitions.reject(&:nested?).reject { anchored.include?(it.name) }

  def anchored = @_anchored ||= @definitions.select(&:nested?).to_set(&:name)

  def target(one) = @census.pinpoint(syntax.segments(one.superclass))

  def syntax = Hashira::Analysis::Syntax

  def settle(name, links)
    trail = [name]
    while (target = links[name]) && !trail.include?(target)
      trail << (name = target)
    end
    target ? trail.drop(trail.index(target)).min : name
  end
end
