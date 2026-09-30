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

  def depth = (0..ranked.size).bsearch { !strong?(ranked.drop(it)) }

  def trim(cut) = cut.reverse.reduce(cut) { |left, edge| settle(left, left - [edge]) }

  def settle(left, lighter) = strong?(@edges - lighter) ? left : lighter

  def strong?(edges)
    links = edges.group_by(&:first).transform_values { |out| out.map { it[1] } }
    [links, Hashira::Coupling::Reach.invert(links)].all? { Hashira::Coupling::Reach.from(@members.first, it) >= whole }
  end

  def whole = @_whole ||= @members.to_set
end
