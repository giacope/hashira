# frozen_string_literal: true

class Hashira::Coupling::Cut
  EXACT = 12

  def initialize(members, edges)
    @members = members
    @edges = edges
  end

  def edges = @_edges ||= backward(order).sort_by { [it.last, *it.first(2)] }

  def exact? = @members.size <= EXACT

  def cost = edges.sum(&:last)

  def order
    nodes = @members.sort
    exact? ? Hashira::Coupling::Ordering.new(nodes, @edges).best : Hashira::Coupling::Sweep.new(nodes, @edges).order
  end

  private

  def backward(order)
    place = order.each_with_index.to_h
    @edges.select { |from, to, _weight| place.fetch(from) > place.fetch(to) }
  end
end
