# frozen_string_literal: true

class Hashira::Coupling::Ordering
  def initialize(nodes, edges)
    @nodes = nodes
    @edges = edges
  end

  def best = unwound((1 << @nodes.size) - 1, [])

  private

  def unwound(set, order)
    return order if set.zero?
    last = choices.fetch(set)
    unwound(set ^ (1 << last), [@nodes[last], *order])
  end

  def choices
    return @_choices if @_choices
    costs = [0]
    @_choices = [nil]
    (1...(1 << @nodes.size)).each { |set| settle(set, costs) }
    @_choices
  end

  def settle(set, costs)
    cost, last = @nodes.each_index.select { set[it] == 1 }.map { [costs[set ^ (1 << it)] + back(it, set), it] }.min
    costs[set] = cost
    @_choices[set] = last
  end

  def back(index, set) = outgoing[index].sum { |bit, weight| set.anybits?(bit) ? weight : 0 }

  def outgoing = @_outgoing ||= @nodes.map { |node| targets(node) }

  def targets(node) = @edges.filter_map { |from, to, weight| [1 << @nodes.index(to), weight] if from == node }
end
