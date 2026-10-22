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
    @_choices ||= (1...(1 << @nodes.size)).each_with_object([[0], [nil]]) do |set, (costs, found)|
      costs[set], found[set] = cheapest(set, costs)
    end.last
  end

  def cheapest(set, costs)
    options =
      @nodes.each_index.filter_map do |index|
        back = outgoing[index].sum { |bit, weight| set.anybits?(bit) ? weight : 0 }
        [costs[set ^ (1 << index)] + back, index] if set[index] == 1
      end
    options.min
  end

  def outgoing
    @_outgoing ||=
      @nodes.map do |node|
        @edges.filter_map { |from, to, weight| [1 << @nodes.index(to), weight] if from == node }
      end
  end
end
