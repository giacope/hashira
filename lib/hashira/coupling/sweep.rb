# frozen_string_literal: true

class Hashira::Coupling::Sweep
  def initialize(nodes, edges)
    @nodes = nodes
    @edges = edges
  end

  def order = settled(peeled(@nodes.to_set, [], []))

  private

  def pairs = @_pairs ||= @edges.to_h { |from, to, weight| [[from, to], weight] }

  def outs = @_outs ||= linked(0)

  def ins = @_ins ||= linked(1)

  def linked(side) = @edges.group_by { it[side] }.transform_values { |list| list.map { [it[1 - side], it.last] } }

  def peeled(left, front, back)
    return front + back if left.empty?
    sink = left.find { weight(outs, it, left).zero? }
    return peeled(left - [sink], front, [sink] + back) if sink
    source = left.min_by { [weight(ins, it, left) - weight(outs, it, left), it] }
    peeled(left - [source], front + [source], back)
  end

  def weight(links, node, among) = links.fetch(node, []).sum { |other, weight| among.include?(other) ? weight : 0 }

  def settled(order)
    gain, from, to = order.each_index.map { Hashira::Coupling::Shift.new(order:, from: it, pairs:).best }.min
    gain.negative? ? settled(order.dup.tap { it.insert(to, it.delete_at(from)) }) : order
  end
end
