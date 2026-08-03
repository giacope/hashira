# frozen_string_literal: true

class Hashira::Coupling::Graph
  def initialize(project, trees, census)
    @census = census
    @map = Hashira::Coupling::EdgeMap.new(census)
    trees.each { |file, tree| @map.record(project.relative(file), file, tree) }
    @cycles = Hashira::Coupling::Cycles.new(@map.dependencies, self)
  end

  attr_reader :cycles

  def packages = (@census.packages | @map.dependencies.keys)

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

  def evidence(from, to) = @map.evidence[[from, to]]

  def usage(package) = incoming(package).to_h { [it, @map.usage[[it, package]]] }

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

  def dependencies = @map.dependencies
end
