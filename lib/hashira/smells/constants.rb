# frozen_string_literal: true

require "prism"

class Hashira::Smells::Constants
  LITERALS = [
    Prism::RegularExpressionNode, Prism::InterpolatedRegularExpressionNode, Prism::StringNode,
    Prism::InterpolatedStringNode, Prism::SymbolNode, Prism::IntegerNode, Prism::FloatNode,
    Prism::RangeNode, Prism::ArrayNode, Prism::HashNode
  ].freeze

  private_constant :LITERALS

  def initialize(walk, catalog)
    @walk = walk
    @catalog = catalog
  end

  def keys(segments) = tables.fetch(segments.join("::"), [])

  def literal?(path) = LITERALS.include?(held[path].class)

  private

  def valued
    @_valued ||= @walk.constants(@catalog).map { |path, constant| [path, Hashira::Analysis::Syntax::Value.new(constant.value).thaw] }
  end

  def held = @_held ||= valued.to_h { |path, value| [path.join("::"), value] }

  def tables
    @_tables ||=
      valued.map { |path, value| [path, chart(value)] }.reject { |_path, keys| keys.empty? }
        .flat_map { |path, keys| path.each_index.map { [path.drop(it).join("::"), keys] } }.to_h
  end

  def chart(value)
    pairs = value.is_a?(Prism::HashNode) ? value.elements : []
    keys = pairs.map { it.is_a?(Prism::AssocNode) ? Hashira::Analysis::Syntax.new(it.key).segments : [] }
    keys.any?(&:empty?) ? [] : keys
  end
end
