# frozen_string_literal: true

require "prism"

class Hashira::Smells::Picks
  FLAGS = [Prism::TrueNode, Prism::FalseNode, Prism::SymbolNode].freeze

  def initialize(definition, calls)
    @definition = definition
    @calls = calls
  end

  def picked?(name) = @calls.any? { FLAGS.include?(argument(it, name).class) }

  private

  def argument(call, name)
    return Hashira::Analysis::Syntax.new(call).option(name) unless positions.include?(name)
    Array(call.arguments&.arguments).grep_v(Prism::KeywordHashNode)[positions.index(name)]
  end

  def positions
    @_positions ||= Hashira::Smells::Parameters.new(@definition).parts.select { positional?(it) }.map(&:name)
  end

  def positional?(part) = part.is_a?(Prism::RequiredParameterNode) || part.is_a?(Prism::OptionalParameterNode)
end
