# frozen_string_literal: true

require "prism"

class Hashira::Smells::Scope
  TYPES = [Prism::ClassNode, Prism::ModuleNode, Prism::SingletonClassNode].freeze

  FENCES = (TYPES + [Prism::DefNode]).freeze

  CLOSURES = [Prism::BlockNode, Prism::LambdaNode].freeze

  LOOPS = (CLOSURES + [Prism::WhileNode, Prism::UntilNode, Prism::ForNode]).freeze

  private_constant :TYPES, :FENCES, :CLOSURES, :LOOPS

  def initialize(node)
    @node = node
  end

  def inside(*fences) = below(FENCES + fences)

  def sweep = below(TYPES)

  def bare = below(FENCES + CLOSURES)

  def fence? = FENCES.include?(@node.class)

  def closure? = CLOSURES.include?(@node.class)

  def loop? = LOOPS.include?(@node.class)

  def covers?(node) = stretch.cover?(Hashira::Smells::Scope.new(node).stretch)

  def stretch
    spot = @node.location
    spot.start_offset..spot.end_offset
  end

  private

  def below(fences)
    found = []
    visit(@node, fences) { found << it }
    found
  end

  def visit(root, fences, &)
    root.compact_child_nodes.each do |child|
      next if fences.include?(child.class)
      yield(child)
      visit(child, fences, &)
    end
  end
end
