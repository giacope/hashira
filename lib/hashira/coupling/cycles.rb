# frozen_string_literal: true

class Hashira::Coupling::Cycles
  def initialize(dependencies, graph)
    @dependencies = dependencies
    @graph = graph
  end

  def through?(package) = !!path(package)

  def path(package) = Hashira::Coupling::CycleSearch.new(@dependencies, package).path

  def knots = @_knots ||= @graph.packages.sort.map { component(it) }.reject(&:empty?).uniq

  def tied?(from, to) = knots.any? { it.include?(from) && it.include?(to) }

  def cut(members) = Hashira::Coupling::Cut.new(members, inside(members), dependents(members))

  private

  def component(package) = (forward.from(package) & Hashira::Coupling::Reach.new(backward).from(package)).sort

  def forward = @_forward ||= Hashira::Coupling::Reach.new(@dependencies)

  def backward = @_backward ||= Hashira::Coupling::Reach.new(@dependencies).inverted

  def dependents(members) = members.to_h { [it, @graph.metric(it).afferent] }

  def inside(members) = members.flat_map { |from| links(from, members) }

  def links(from, members) = (@dependencies.fetch(from, []).to_a & members).map { [from, it, @graph.weight(from, it)] }
end
