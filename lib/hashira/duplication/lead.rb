# frozen_string_literal: true

require "prism"

class Hashira::Duplication::Lead
  DEFINERS = %i[test it specify example].freeze

  def initialize(statements)
    @statements = statements
  end

  def calls?(names) = call.any? { it.is_a?(Prism::CallNode) && names.include?(it.name) }

  def handed = call.flat_map { [it.arguments, it.block] }

  def named = definer? ? opening.flat_map { [it, *Hashira::Analysis::NodeWalk.new(it.arguments).collect] } : []

  private

  def call = definer? ? opening.flat_map { lone(it.block.body) } : opening

  def opening = @_opening ||= lone(@statements)

  def lone(statements)
    nodes = statements.is_a?(Prism::StatementsNode) ? statements.body : Array(statements)
    nodes.one? ? nodes : []
  end

  def definer? = opening.any? { definition?(it) }

  def definition?(node)
    node.is_a?(Prism::CallNode) && !node.receiver && DEFINERS.include?(node.name) && node.block.is_a?(Prism::BlockNode)
  end
end
