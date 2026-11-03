# frozen_string_literal: true

require "prism"

class Hashira::Smells::Writes
  LITERALS = [Prism::HashNode, Prism::KeywordHashNode, Prism::ArrayNode, Prism::StringNode].freeze

  private_constant :LITERALS

  def initialize(definition)
    @node = definition
  end

  def of(name) = body.grep(Prism::LocalVariableWriteNode).select { it.name == name }

  def built?(name) = of(name).any? { LITERALS.include?(it.value.class) }

  private

  def body = @_body ||= Hashira::Smells::Scope.new(@node).inside
end
