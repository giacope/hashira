# frozen_string_literal: true

require "prism"

class Hashira::Smells::Handle
  def initialize(node)
    @node = node
  end

  def to_s
    return "#{@node.receiver.slice}[#{@node.arguments.slice}]" if index?
    given = parts
    given.empty? ? title : "#{title}(#{given.join(", ")})"
  end

  private

  def title = [@node.receiver&.slice, @node.name].compact.join(@node.safe_navigation? ? "&." : ".")

  def parts
    passed = @node.block.is_a?(Prism::BlockArgumentNode) ? [@node.block.slice] : []
    ([@node.arguments&.slice] + passed).compact
  end

  def index? = @node.name == :[] && @node.receiver && @node.arguments
end
