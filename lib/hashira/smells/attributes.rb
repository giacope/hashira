# frozen_string_literal: true

require "prism"

class Hashira::Smells::Attributes
  READERS = %i[attr_reader attr_accessor].freeze

  WRITERS = %i[attr_writer attr_accessor].freeze

  EVERY = %i[attr_reader attr_writer attr_accessor].freeze

  private_constant :READERS, :WRITERS, :EVERY

  def initialize(nodes)
    @nodes = nodes
  end

  def declared(kinds = EVERY) = macros(kinds).flat_map { names(it) }

  def readers = declared(READERS)

  def macros(kinds = EVERY) = @nodes.grep(Prism::CallNode).select { kinds.include?(it.name) && !it.receiver }

  def writers = declared(WRITERS).map { :"#{it}=" }

  private

  def names(call)
    Array(call.arguments&.arguments).grep(Prism::SymbolNode).map { Hashira::Analysis::Syntax::Word.new(it).to_s }
  end
end
