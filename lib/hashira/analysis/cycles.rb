# frozen_string_literal: true

class Hashira::Analysis::Cycles
  def initialize(dependencies, graph)
    @dependencies = dependencies
    @graph = graph
  end

  def through?(package) = !!path(package)

  def path(package) = Hashira::Analysis::CycleSearch.new(@dependencies, package).path

  def weakest(trail) = trail.each_cons(2).min_by { |from, to| @graph.weight(from, to) }
end
