# frozen_string_literal: true

class Hashira::Coupling::Sweep
  OUT = 0
  IN = 1

  def initialize(nodes, edges)
    @nodes = nodes
    @edges = edges
  end

  def order = settled(peeled(@nodes.to_set, [], []))

  private

  def pairs = @_pairs ||= @edges.to_h { |from, to, weight| [[from, to], weight] }

  def links = @_links ||= [OUT, IN].map { linked(it) }

  def linked(side) = @edges.group_by { it[side] }.transform_values { |list| list.map { [it[1 - side], it.last] } }

  def peeled(left, front, back)
    return front + back if left.empty?
    sink = left.find { weight(OUT, it, left).zero? }
    return peeled(left - [sink], front, [sink] + back) if sink
    source = left.min_by { [weight(IN, it, left) - weight(OUT, it, left), it] }
    peeled(left - [source], front + [source], back)
  end

  def weight(side, node, among) = links[side].fetch(node, []).sum { |other, weight| among.include?(other) ? weight : 0 }

  def settled(order)
    gain, from, to = order.each_index.map { Hashira::Coupling::Shift.new(order:, from: it, pairs:).best }.min
    gain.negative? ? settled(order.dup.tap { it.insert(to, it.delete_at(from)) }) : order
  end
end
