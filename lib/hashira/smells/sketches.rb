# frozen_string_literal: true

require "prism"

class Hashira::Smells::Sketches
  include Enumerable

  def initialize(found, catalog, concerns = Hashira::Smells::Concerns.new(found))
    @found = found
    @catalog = catalog
    @concerns = concerns
  end

  def each(&) = ordered.map { sketch(*it) }.each(&)

  private

  def sketch(name, node, file, lexical)
    sort = Hashira::Smells::Sort.new(kinds.fetch(name, kind(node)), !@concerns.loose?(name), @catalog.claimed?(lexical))
    Hashira::Smells::Sketch.new(name, node, file, sort)
  end

  def ordered = @found.partition { |_name, node| !opened?(node) }.flatten(1)

  def kinds = @_kinds ||= @found.reject { |_name, node| opened?(node) }.to_h { |name, node| [name, kind(node)] }

  def opened?(node) = node.is_a?(Prism::BlockNode)

  def kind(node) = node.is_a?(Prism::ClassNode) ? :class : :module
end
