# frozen_string_literal: true

class Hashira::Coupling::Graph
  def initialize(project, trees, census)
    @project = project
    @census = census
    @trees = trees
  end

  attr_reader :trees

  def unfolded = @_unfolded ||= self.class.new(@project, @trees, @census.unfolded)

  def cycles = @_cycles ||= Hashira::Coupling::Cycles.new(links, self)

  def charge(file) = @census.charge(file, [])

  def packages = (@census.packages | dependencies.keys)

  def packaging = @census.packaging

  def folds = @census.folds

  def outgoing(package) = dependencies[package].to_a.sort

  def incoming(package) = sources(dependencies, package)

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

  def domain = edges.reject { web?(it.from) || web?(it.to) }

  def usage(package) = clients(package).to_h { [it, map.usage[[it, package]]] }

  def constants(edge)
    from, to = edge.deconstruct
    map.usage[[from, to]].sort
  end

  def metric(package)
    Hashira::Coupling::Metric.new(
      types: @census.types[package],
      afferent: clients(package).size,
      efferent: links[package].size
    )
  end

  def metrics = packages.to_h { [it, metric(it)] }

  def violations = Hashira::Coupling::SdpCheck.new(links, metrics).violations.reject { cycles.tied?(*it) }

  def weight(from, to) = evidence(from, to).size

  private

  def map
    @_map ||=
      Hashira::Coupling::EdgeMap.new(@census).tap do |edges|
        @trees.each { |file, tree| edges.record(@project.relative(file), file, tree) }
      end
  end

  def dependencies = map.dependencies

  def links = @_links ||= packages.to_h { |package| [package, dependencies[package].reject { web?(it) }.to_set] }

  def clients(package) = sources(links, package)

  def sources(targets, package) = packages.select { targets[it].include?(package) }.sort

  def web?(package) = @census.web?(package)
end
