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

  def argument(call, name) = positions.include?(name) ? passed(call)[positions.index(name)] : keyed(call, name)

  def positions = @_positions ||= Hashira::Smells::Parameters.parts(@definition).select { positional?(it) }.map(&:name)

  def positional?(part) = part.is_a?(Prism::RequiredParameterNode) || part.is_a?(Prism::OptionalParameterNode)

  def passed(call) = given(call).grep_v(Prism::KeywordHashNode)

  def keyed(call, name) = Hashira::Analysis::Syntax.option(call, name)

  def given(call) = Array(call.arguments&.arguments)
end
