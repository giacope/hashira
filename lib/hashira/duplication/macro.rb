# frozen_string_literal: true

require "prism"

class Hashira::Duplication::Macro
  LINKS = 4
  READS = [Prism::LocalVariableReadNode, Prism::ItLocalVariableReadNode].freeze
  DEFERRED = [Prism::CallNode, Prism::OrNode].freeze

  def initialize(call)
    @call = call
  end

  def pardoned = [*deferred, *block].flat_map { Hashira::Analysis::NodeWalk.new(it).collect }

  private

  def deferred
    options = Array(@call.arguments&.arguments).grep(Prism::KeywordHashNode).flat_map(&:elements).grep(Prism::AssocNode)
    options.map(&:value).select { it.is_a?(Prism::LambdaNode) && lone(it).any? { DEFERRED.include?(it.class) } }
  end

  def block = [@call.block].select { passed?(it) || reader?(it) }

  def passed?(block) = (block in Prism::BlockArgumentNode[expression: Prism::SymbolNode])

  def reader?(block) = block.is_a?(Prism::BlockNode) && lone(block).any? { chain?(links(it)) }

  def chain?(links) = links.size <= LINKS && links.all? { plain?(it) }

  def links(node)
    receiver = node.receiver if node.is_a?(Prism::CallNode)
    receiver ? [node, *links(receiver)] : [node]
  end

  def plain?(link) = link.is_a?(Prism::CallNode) ? !(link.arguments || link.block) : READS.include?(link.class)

  def lone(node)
    statements = Array(node.body&.compact_child_nodes)
    statements.one? ? statements : []
  end
end
