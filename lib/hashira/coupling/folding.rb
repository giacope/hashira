# frozen_string_literal: true

require "prism"

class Hashira::Coupling::Folding
  SUFFIXES = %w[Resource Serializer Policy Decorator].freeze

  MIXINS = %i[extend include].freeze

  KINDS = %w[base mixin suffix plural].freeze

  def initialize(definitions, roster, scope, framework)
    @definitions = definitions
    @roster = roster
    @scope = scope
    @framework = framework
  end

  def map = @_map ||= links.keys.to_h { [it, settle(it, links)] }.reject { |from, to| from == to }

  def disclosed = map.map { |from, to| Hashira::Coupling::Fold.new(from, to, KINDS[kinds.index { it.key?(from) }]) }

  private

  def kinds = @_kinds ||= [parents, mixins, named, plurals]

  def links = @_links ||= kinds.reverse.reduce(:merge)

  def parents
    @_parents ||= singles.select { |_name, kin| kin.parent.any? }.to_h { |name, kin| [name, target(kin)] }.compact
  end

  def named = singles.keys.to_h { [it, crop(it)] }.select { |_name, stem| stem && packages.include?(stem) }

  def packages = @_packages ||= @roster.to_a

  def suffixes = @framework.rails? ? SUFFIXES : []

  def crop(name)
    suffix = suffixes.find { trims?(name, it) }
    suffix && name.delete_suffix(suffix)
  end

  def trims?(name, suffix) = name.end_with?(suffix) && name != suffix

  def plurals = known.map { [inflection.plural(it), it] }.select { |many, one| plural?(many, one) }.to_h

  def inflection = @_inflection ||= @framework.inflection

  def plural?(many, one) = many != one && known.include?(many)

  def known = @_known ||= packages.to_set

  def mixins = badges.flat_map { |name, badge| adopted(badge).map { [name, it] } }.to_h

  def badges
    named = lone.group_by { it.to_a.first }
    named.select { |_name, ones| ones.all? { badge?(it.form) } }.transform_values { it.first.form }
  end

  def badge?(form)
    form.type? && !form.klass? && form.to_a.all? { Hashira::Analysis::Syntax::Call.new(it).macro?(MIXINS) }
  end

  def adopted(badge) = badge.to_a.flat_map { it.arguments.arguments }.lazy.filter_map { pinpoint(it) }.first(1)

  def singles
    @_singles ||=
      lone.select { it.form.klass? }.group_by { it.to_a.first }.transform_values do |ones|
        (ones.find { it.kin.parent.any? } || ones.last).kin
      end
  end

  def lone = @_lone ||= @definitions.reject { it.site.nested? || it.to_a.empty? || anchored.include?(it.to_a.first) }

  def anchored = @_anchored ||= @definitions.select { it.site.nested? }.to_set { it.to_a.first }

  def target(kin) = pinpoint(kin.parent.first)

  def pinpoint(node) = @scope.pinpoint(Hashira::Analysis::Syntax.new(node).segments)

  def settle(name, links)
    trail = [name]
    while (target = links[name]) && !trail.include?(target)
      trail << (name = target)
    end
    target ? trail.drop(trail.index(target)).min(1).fetch(0) : name
  end
end
