# frozen_string_literal: true

require "prism"

class Hashira::Analysis::Syntax
  def initialize(node)
    @node = node
  end

  def segments
    case @node
    when Prism::ConstantReadNode then [@node.name.to_s]
    when Prism::ConstantPathNode then Hashira::Analysis::Syntax.new(@node.parent).segments + [@node.name.to_s]
    else []
    end
  end

  def static?
    case @node
    when Prism::ConstantReadNode then true
    when Prism::ConstantPathNode then anchored?
    else false
    end
  end

  def rooted?
    return false unless @node.is_a?(Prism::ConstantPathNode)
    parent = @node.parent
    !parent || Hashira::Analysis::Syntax.new(parent).rooted?
  end

  def place(stack, roots) = rooted? ? segments : anchor(stack, segments, roots)

  private

  def anchored?
    parent = @node.parent
    !parent || Hashira::Analysis::Syntax.new(parent).static?
  end

  def anchor(stack, segments, roots)
    return (stack.last || []) + segments if segments.length < 2 || !roots
    base = stack.reverse_each.find { roots.include?(it + segments.first(1)) }
    base ? base + segments : hoist(stack, segments, roots)
  end

  def hoist(stack, segments, roots)
    roots.include?(segments.first(1)) ? segments : (stack.last || []) + segments
  end
end
