# frozen_string_literal: true

require "prism"

class Hashira::Coupling::Folding
  SUFFIXES = %w[Resource Serializer Policy Decorator].freeze

  MIXINS = %i[extend include].freeze

  KINDS = %w[base mixin suffix plural].freeze

  def initialize(definitions, census, rails:)
    @definitions = definitions
    @census = census
    @rails = rails
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

  def named = singles.keys.to_h { [it, crop(it)] }.select { |_name, stem| stem && @census.packages.include?(stem) }

  def suffixes = @rails ? SUFFIXES : []

  def crop(name)
    suffix = suffixes.find { trims?(name, it) }
    suffix && name.delete_suffix(suffix)
  end

  def trims?(name, suffix) = name.end_with?(suffix) && name != suffix

  def plurals = known.map { [@census.plural(it), it] }.select { |many, one| plural?(many, one) }.to_h

  def plural?(many, one) = many != one && known.include?(many)

  def known = @_known ||= @census.packages.to_set

  def mixins = badges.flat_map { |name, badge| adopted(badge).map { [name, it] } }.to_h

  def badges = lone.group_by(&:name).select { |_name, ones| ones.all? { badge?(it) } }.transform_values(&:first)

  def badge?(definition) = definition.module? && syntax(definition.node).statements.all? { syntax(it).macro?(MIXINS) }

  def adopted(badge) = adoptions(badge).lazy.filter_map { @census.pinpoint(syntax(it).segments) }.first(1)

  def adoptions(badge) = syntax(badge.node).statements.flat_map { it.arguments.arguments }

  def singles
    @_singles ||= lone.select(&:klass?).group_by(&:name).transform_values { it.find(&:superclass) || it.last }
  end

  def lone = @_lone ||= @definitions.reject { it.nested? || it.path.empty? || anchored.include?(it.name) }

  def anchored = @_anchored ||= @definitions.select(&:nested?).to_set(&:name)

  def target(one) = @census.pinpoint(syntax(one.superclass).segments)

  def syntax(node) = Hashira::Analysis::Syntax.new(node)

  def settle(name, links)
    trail = [name]
    while (target = links[name]) && !trail.include?(target)
      trail << (name = target)
    end
    target ? trail.drop(trail.index(target)).min(1).fetch(0) : name
  end
end
