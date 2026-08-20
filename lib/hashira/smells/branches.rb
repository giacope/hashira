# frozen_string_literal: true

require "prism"

class Hashira::Smells::Branches
  def initialize(root)
    @root = root
  end

  def together?(nodes) = nodes.combination(2).any? { |left, right| meet?(trail(left), trail(right)) }

  private

  def meet?(left, right) = shared(left, right).none? { parted?(*it) }

  def shared(left, right) = left.zip(right).select(&:last)

  def parted?(here, there) = here.first.equal?(there.first) && here.last != there.last

  def trail(node) = trails.fetch(node)

  def trails
    return @_trails if @_trails
    @_trails = {}.compare_by_identity
    chart(@root, [])
    @_trails
  end

  def chart(node, trail)
    @_trails[node] = trail
    node.compact_child_nodes.each { chart(it, trail + taken(node, it)) }
  end

  def taken(node, child)
    return arm_for(node, child) if node.is_a?(Prism::BeginNode)
    arm = arms(node).index { it.equal?(child) }
    arm ? [[node, arm]] : []
  end

  def arm_for(node, child)
    rescued = node.rescue_clause
    return [] unless [node.statements, rescued, node.else_clause].any? { it.equal?(child) }
    [[node, rescued.equal?(child) ? 1 : 0]]
  end

  def arms(node) = (clauses(node) || conditions(node)).compact

  def clauses(node)
    case node
    when Prism::IfNode, Prism::RescueNode then [node.statements, node.subsequent]
    when Prism::UnlessNode then [node.statements, node.else_clause]
    when Prism::RescueModifierNode then [node.expression, node.rescue_expression]
    end
  end

  def conditions(node)
    case node
    when Prism::CaseNode, Prism::CaseMatchNode then node.conditions + [node.else_clause]
    else []
    end
  end
end
