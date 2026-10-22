# frozen_string_literal: true

require "prism"

class Hashira::Duplication::Lead
  DEFINERS = %i[test it specify example].freeze

  def initialize(statements)
    @statements = statements
  end

  def calls?(names) = call.then { it.is_a?(Prism::CallNode) && names.include?(it.name) }

  def handed = call.then { [it.arguments, it.block] }

  def named = definer? ? [opening, *Hashira::Analysis::NodeWalk.new(opening.arguments).collect] : []

  private

  def call = definer? ? lone(opening.block.body) : opening

  def opening = @_opening ||= lone(@statements)

  def lone(statements)
    nodes = statements.is_a?(Prism::StatementsNode) ? statements.body : Array(statements)
    nodes.first if nodes.one?
  end

  def definer?
    node = opening
    node.is_a?(Prism::CallNode) && !node.receiver && DEFINERS.include?(node.name) && node.block.is_a?(Prism::BlockNode)
  end
end
