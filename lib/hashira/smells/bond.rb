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

  def bonds(name) = keys(name).map { [it, name] } + words(option("through")).map { [name, it] }

  def keys(name)
    return [] unless @call.name == OWNER
    key = [*words(option("foreign_key")), :"#{name}_id"].first
    option("polymorphic").is_a?(Prism::TrueNode) ? [key, :"#{name}_type"] : [key]
  end

  def option(key) = Hashira::Analysis::Syntax.new(@call).option(key)

  def words(node)
    syntax = Hashira::Analysis::Syntax.new(node)
    syntax.word? ? [syntax.symbol] : []
  end
end
