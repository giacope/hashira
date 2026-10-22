# frozen_string_literal: true

class Hashira::Coupling::Cut
  EXACT = 12

  def initialize(members, edges, depth)
    @members = members
    @edges = edges
    @depth = depth
  end

  def edges = @_edges ||= backward(order).sort_by { [it.last, *it.first(2)] }

  def exact? = @members.size <= EXACT

  def cost = edges.sum(&:last)

  def order
    nodes = @members.sort_by { [-@depth.fetch(it), it] }
    return Hashira::Coupling::Ordering.new(nodes, @edges).best if exact?
    Hashira::Coupling::Sweep.new(nodes, @edges, @depth).order
  end

  private

  def backward(order)
    place = order.each_with_index.to_h
    @edges.select { |from, to, _weight| order.first(place.fetch(from)).include?(to) }
  end
end
