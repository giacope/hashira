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

  def outgoing(package) = map.outgoing(package).to_a.sort

  def incoming(package) = packages.select { map.outgoing(it).include?(package) }.sort

  def edges
    dependencies.sort.flat_map { |from, tos| tos.sort.map { Hashira::Coupling::Edge.new(from:, to: it) } }
  end

  def weighted = edges.map { [it.from, it.to, weight(it)] }

  def departures(package) = outgoing(package).map { [it, weight(edge(package, it))] }

  def refs(edge) = evidence(edge).to_a.sort

  def evidence(edge) = map.evidence(edge)

  def sources(edge) = map.sources(edge).to_a.sort

  def usage(package) = incoming(package).to_h { [it, map.usage(edge(it, package))] }

  def constants(edge) = map.usage(edge).sort

  def metric(package)
    Hashira::Coupling::Metric.new(
      types: @census.types[package],
      afferent: incoming(package).size,
      efferent: map.outgoing(package).size
    )
  end

  def metrics = packages.to_h { [it, metric(it)] }

  def violations = Hashira::Coupling::SdpCheck.new(dependencies, metrics).violations

  def weight(edge) = evidence(edge).size

  private

  def edge(from, to) = Hashira::Coupling::Edge.new(from, to)

  def map
    @_map ||=
      Hashira::Coupling::EdgeMap.new(@census).tap do |edges|
        @trees.each { |file, tree| edges.record(@project.relative(file), file, tree) }
      end
  end

  def dependencies = map.dependencies
end
