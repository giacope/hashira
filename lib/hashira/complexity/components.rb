# frozen_string_literal: true

class Hashira::Complexity::Components
  ENTER = :enter

  LEAVE = :leave

  def initialize(graph)
    @graph = graph
  end

  def to_a
    assigned = Set.new
    back = transposed
    finished.reverse_each.filter_map do |root|
      next if assigned.include?(root)
      found = flood(root, assigned, back)
      assigned.merge(found)
      found
    end
  end

  private

  def finished
    seen = Set.new
    order = []
    stack = entries(@graph.keys)
    until stack.empty?
      step, node = stack.pop
      next order << node if step == LEAVE
      stack.push([LEAVE, node], *entries(@graph.fetch(node))) if seen.add?(node)
    end
    order
  end

  def entries(nodes) = nodes.reverse.map { [ENTER, it] }

  def flood(root, assigned, back)
    seen = Set[root]
    found = [root]
    found.each { |node| found.concat(back.fetch(node, []).select { !assigned.include?(it) && seen.add?(it) }) }
  end

  def transposed
    edges = @graph.flat_map { |node, children| children.map { [it, node] } }
    edges.group_by(&:first).transform_values { it.map(&:last) }
  end
end
