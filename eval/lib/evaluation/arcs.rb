# frozen_string_literal: true

class Evaluation::Arcs
  SUBSETS = 18

  ORDERINGS = 16

  def initialize(edges)
    @edges = edges
  end

  def minimum
    return subsets if @edges.size <= SUBSETS
    orderings if nodes.size <= ORDERINGS
  end

  def breaks?(cut)
    removed = cut.map { it.first(2) }
    ordered?(@edges.reject { removed.include?(it.first(2)) })
  end

  def nodes = @_nodes ||= @edges.flat_map { it.first(2) }.uniq.sort

  private

  def subsets = (0...(1 << @edges.size)).reduce(@edges.sum(&:last)) { |best, mask| trial(mask, best) }

  def trial(mask, best)
    removed = @edges.select.with_index { |_edge, index| mask[index] == 1 }
    weight = removed.sum(&:last)
    weight < best && ordered?(@edges - removed) ? weight : best
  end

  def ordered?(edges)
    degree = in_degree(edges)
    ready = nodes.reject { degree[it].positive? }
    ready.each { |node| edges.each { |from, to| ready << to if from == node && (degree[to] -= 1).zero? } }
    ready.size == nodes.size
  end

  def in_degree(edges) = edges.each_with_object(Hash.new(0)) { |(_from, to), counts| counts[to] += 1 }

  def orderings
    table = { 0 => 0 }
    (1...(1 << nodes.size)).each { |set| table[set] = placed(set, table) }
    table[(1 << nodes.size) - 1]
  end

  def placed(set, table)
    nodes.each_index.filter_map { |index| table[set ^ (1 << index)] + back(index, set) if set[index] == 1 }.min
  end

  def back(index, set) = outgoing[index].sum { |bit, weight| set.nobits?(bit) ? 0 : weight }

  def outgoing = @_outgoing ||= nodes.map { |node| targets(node) }

  def targets(node) = @edges.select { it.first == node && it[1] != node }.map { [1 << nodes.index(it[1]), it.last] }
end
