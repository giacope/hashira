# frozen_string_literal: true

class Hashira::Coupling::Cycles
  def initialize(dependencies, graph)
    @dependencies = dependencies
    @graph = graph
  end

  def through?(package) = !!path(package)

  def path(package) = Hashira::Coupling::CycleSearch.new(@dependencies, package).path

  def knots = @_knots ||= @graph.packages.sort.map { component(it) }.reject(&:empty?).uniq

  def cut(members) = Hashira::Coupling::Cut.new(members, inside(members)).edges

  private

  def component(package) = (reach(package, @dependencies) & reach(package, backward)).sort

  def reach(package, links) = Hashira::Coupling::Reach.from(package, links)

  def backward = @_backward ||= Hashira::Coupling::Reach.invert(@dependencies)

  def inside(members) = members.flat_map { |from| links(from, members) }

  def links(from, members) = (@dependencies.fetch(from, []).to_a & members).map { [from, it, @graph.weight(from, it)] }
end
