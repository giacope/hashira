# frozen_string_literal: true

require "prism"

class Hashira::Smells::Rivals
  STAND_IN = /\A(?:Fake|Null|Stub|Dummy)(?:s?\z|[[:upper:]])|[[:lower:]](?:Stub|Fake|Double)s?\z/

  FORKS = [Prism::IfNode, Prism::UnlessNode, Prism::OrNode].freeze

  def initialize(types, lineage)
    @types = types
    @lineage = lineage
  end

  def of(name) = links.fetch(name, Set.new)

  private

  def links = @_links ||= pairs.each_with_object({}) { |pair, found| bind(found, *pair) }

  def pairs = (sites + doubles + subsets).flat_map { it.uniq.combination(2).to_a }

  def bind(found, left, right)
    (found[left] ||= Set.new) << right
    (found[right] ||= Set.new) << left
  end

  def sites = @types.flat_map { |type| forks(type).map { made(type, it) } }

  def forks(type) = Hashira::Smells::Scope.sweep(type.node).select { FORKS.include?(it.class) }

  def made(type, fork) = outcomes(fork).filter_map { built(type, it) }

  def outcomes(node) = choices(node)&.flat_map { outcomes(it) } || [node]

  def choices(node)
    case node
    when Prism::IfNode, Prism::UnlessNode then node.compact_child_nodes.drop(1)
    when Prism::OrNode then node.compact_child_nodes
    when Prism::ElseNode, Prism::ParenthesesNode, Prism::StatementsNode then node.compact_child_nodes.last(1)
    end
  end

  def built(type, node)
    return unless node.is_a?(Prism::CallNode) && node.name == :new
    @lineage.resolve(type.name, Hashira::Analysis::Syntax.segments(node.receiver))
  end

  def doubles = names.flat_map { |name| originals(name).map { [name, it] } }

  def originals(name)
    *space, leaf = name.split("::")
    model = [*space.grep_v(STAND_IN), leaf].join("::")
    model == name ? [] : names.select { it == model || it.end_with?("::#{model}") }
  end

  def subsets = names.select { STAND_IN.match?(leaf(it)) && publics(it).any? }.flat_map { fits(it) }

  def fits(name) = names.select { it != name && publics(name).subset?(publics(it)) }.map { [name, it] }

  def publics(name) = surface.fetch(name)

  def surface = @_surface ||= @types.group_by(&:name).transform_values { exposed(it) }

  def exposed(kin)
    kin.flat_map { Hashira::Smells::Visibility.new(it.node).entries }
      .filter_map { |definition, section| definition.name if section == :public && !definition.receiver }
      .to_set - [:initialize]
  end

  def names = surface.keys

  def leaf(name) = name.split("::").last
end
