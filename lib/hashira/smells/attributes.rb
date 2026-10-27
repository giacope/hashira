# frozen_string_literal: true

require "prism"

class Hashira::Smells::Attributes
  READERS = %i[attr_reader attr_accessor].freeze

  WRITERS = %i[attr_writer attr_accessor].freeze

  EVERY = %i[attr_reader attr_writer attr_accessor].freeze

  def initialize(nodes)
    @nodes = nodes
  end

  def declared(kinds = EVERY) = macros(kinds).flat_map { names(it) }

  def macros(kinds) = @nodes.grep(Prism::CallNode).select { kinds.include?(it.name) && !it.receiver }

  def ivars(kinds) = @nodes.select { kinds.include?(it.class) }.map(&:name)

  private

  def names(call)
    Array(call.arguments&.arguments).grep(Prism::SymbolNode).map { Hashira::Analysis::Syntax.new(it).text }
  end
end
