# frozen_string_literal: true

require "prism"

class Hashira::Smells::Rivals
  STAND_IN = /\A(?:Fake|Null|Stub|Dummy|Mock)(?:s?\z|[[:upper:]])|[[:lower:]](?:Stub|Fake|Double|Mock)s?\z/

  PLACES = [Prism::IfNode, Prism::UnlessNode, Prism::OrNode, Prism::ArrayNode, Prism::HashNode].freeze

  def initialize(types, typeset)
    @types = types
    @typeset = typeset
  end

  def of(name) = links.fetch(name, Set.new)

  def sides(name) = Hashira::Smells::Sides.new(surface).of(name)

  private

  def links
    @_links ||=
      meetings.flat_map { it.uniq.combination(2).to_a }.flat_map { [it, it.reverse] }
        .group_by(&:first).transform_values { it.to_set(&:last) }
  end

  def meetings
    seats = Hashira::Smells::Seats.new(@types, @typeset)
    sites + doubles + subsets + seats.slots + seats.wraps
  end

  def sites
    @types.flat_map do |type|
      places = type.accept(Hashira::Smells::Scope).sweep.select { PLACES.include?(it.class) }
      places.map { |place| outcomes(place).flat_map { built(type, it) } }
    end
  end

  def outcomes(node)
    choices =
      case node
      when Prism::IfNode, Prism::UnlessNode then node.compact_child_nodes.drop(1)
      when Prism::OrNode then node.compact_child_nodes
      when Prism::ArrayNode, Prism::HashNode then entries(node)
      when Prism::ElseNode, Prism::ParenthesesNode, Prism::StatementsNode then node.compact_child_nodes.last(1)
      end
    choices&.flat_map { outcomes(it) } || [node]
  end

  def entries(node) = node.elements.map { it.is_a?(Prism::AssocNode) ? it.value : it }

  def built(type, node)
    held = node.is_a?(Prism::CallNode) && node.name == :new ? node.receiver : node
    @typeset.resolve(type.to_s, Hashira::Analysis::Syntax.new(held).segments)
  end

  def doubles
    names.flat_map do |name|
      *space, leaf = name.split("::")
      model = [*space.grep_v(STAND_IN), leaf].join("::")
      model == name ? [] : names.select { it == model || it.end_with?("::#{model}") }.map { [name, it] }
    end
  end

  def subsets
    stand_ins = names.select { STAND_IN.match?(it.split("::").last) && publics(it).any? }
    stand_ins.flat_map { |name| names.select { it != name && publics(name).subset?(publics(it)) }.map { [name, it] } }
  end

  def publics(name) = surface.fetch(name)

  def surface = @_surface ||= @types.group_by(&:to_s).transform_values { exposed(it) }

  def exposed(kin)
    kin.flat_map { it.accept(Hashira::Analysis::TypeWalk).sections }
      .filter_map { |definition, section| definition.name if section == :public && !definition.receiver }
      .to_set - [:initialize]
  end

  def names = surface.keys
end
