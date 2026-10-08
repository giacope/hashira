# frozen_string_literal: true

class Hashira::Coupling::Cut
  def initialize(members, edges)
    @members = members
    @edges = edges
  end

  def edges = @_edges ||= trim(ranked.first(depth))

  private

  def ranked = @_ranked ||= @edges.sort_by { rank(it) }

  def rank(edge) = [edge.last, *edge.first(2)]

  def depth = (0..ranked.size).bsearch { split?(ranked.drop(it)) }

  def trim(cut) = cut.reverse.reduce(cut) { |left, edge| settle(left, left - [edge]) }

  def settle(left, lighter) = split?(@edges - lighter) ? lighter : left

  def split?(edges) = largest(edges) <= @members.size / 2

  def largest(edges)
    links = edges.group_by(&:first).transform_values { |out| out.map { it[1] } }
    backward = Hashira::Coupling::Reach.invert(links)
    @members.map { (reach(it, links) & reach(it, backward)).size }.max
  end

  def reach(member, links) = Hashira::Coupling::Reach.from(member, links)
end
