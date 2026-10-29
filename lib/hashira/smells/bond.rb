# frozen_string_literal: true

require "prism"

class Hashira::Smells::Bond
  OWNER = :belongs_to

  def initialize(call)
    @call = call
  end

  def pairs
    return [] unless Hashira::Analysis::Syntax.new(@call).bare?
    words(@call.arguments.arguments.first).flat_map { bonds(it) }
  end

  private

  def bonds(name) = keys(name).map { [it, name] } + option("through").flat_map { words(it) }.map { [name, it] }

  def keys(name)
    return [] unless @call.name == OWNER
    key = [*option("foreign_key").flat_map { words(it) }, :"#{name}_id"].first
    option("polymorphic").any?(Prism::TrueNode) ? [key, :"#{name}_type"] : [key]
  end

  def option(key) = Hashira::Analysis::Syntax.new(@call).given(key)

  def words(node) = Hashira::Analysis::Syntax.new(node).words
end
