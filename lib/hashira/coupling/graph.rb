# frozen_string_literal: true

class Hashira::Coupling::Graph
  def initialize(project, trees, census)
    @project = project
    @census = census
    @trees = trees
  end

  attr_reader :trees

  def cycles = @_cycles ||= Hashira::Coupling::Cycles.new(map.dependencies, self)

  def charge(file) = @census.charge(file, [])

  def packages = (@census.packages | dependencies.keys)

  def packaging = @census.packaging

  def folds = @census.folds

  def outgoing(package) = dependencies[package].to_a.sort

  def incoming(package) = packages.select { dependencies[it].include?(package) }.sort

  def edges
    dependencies.sort.flat_map { |from, tos| tos.sort.map { Hashira::Coupling::Edge.new(from:, to: it) } }
  end

  def weighted
    edges.map do |edge|
      from, to = edge.deconstruct
      [from, to, weight(from, to)]
    end
  end

  def evidence(from, to) = map.evidence[[from, to]]

  def usage(package) = incoming(package).to_h { [it, map.usage[[it, package]]] }

  def constants(edge)
    from, to = edge.deconstruct
    map.usage[[from, to]].sort
  end

  def metric(package)
    Hashira::Coupling::Metric.new(
      types: @census.types[package],
      afferent: incoming(package).size,
      efferent: dependencies[package].size
    )
  end

  def metrics = packages.to_h { [it, metric(it)] }

  def violations = Hashira::Coupling::SdpCheck.new(dependencies, metrics).violations

  def weight(from, to) = evidence(from, to).size

  private

  def map
    @_map ||=
      Hashira::Coupling::EdgeMap.new(@census).tap do |edges|
        @trees.each { |file, tree| edges.record(@project.relative(file), file, tree) }
      end
  end

  def dependencies = map.dependencies
end
