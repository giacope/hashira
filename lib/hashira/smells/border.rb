# frozen_string_literal: true

require "prism"

class Hashira::Smells::Border
  FENCES = [Prism::ClassNode, Prism::ModuleNode, Prism::SingletonClassNode, Prism::DefNode].freeze

  CLOSURES = [Prism::BlockNode, Prism::LambdaNode].freeze

  LOOPS = (CLOSURES + [Prism::WhileNode, Prism::UntilNode, Prism::ForNode]).freeze

  private_constant :FENCES, :CLOSURES, :LOOPS

  def initialize(node)
    @node = node
  end

  def fence? = FENCES.include?(@node.class)

  def closure? = CLOSURES.include?(@node.class)

  def loop? = LOOPS.include?(@node.class)
end
