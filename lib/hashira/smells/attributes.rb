# frozen_string_literal: true

require "prism"

module Hashira::Smells::Attributes
  READERS = %i[attr_reader attr_accessor].freeze

  EVERY = %i[attr_reader attr_writer attr_accessor].freeze

  module_function

  def declared(nodes, kinds = EVERY) = macros(nodes, kinds).flat_map { names(it) }

  def macros(nodes, kinds) = nodes.grep(Prism::CallNode).select { kinds.include?(it.name) && !it.receiver }

  def ivars(nodes, kinds) = nodes.select { kinds.include?(it.class) }.map(&:name)

  def names(call) = Array(call.arguments&.arguments).grep(Prism::SymbolNode).map(&:unescaped)
end
