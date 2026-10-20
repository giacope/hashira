# frozen_string_literal: true

class Hashira::Coupling::Graph
  def initialize(project, trees, census)
    @project = project
    @census = census
    @trees = trees
  end

  attr_reader :trees, :census

  def unfolded = @_unfolded ||= self.class.new(@project, @trees, @census.unfolded)

  def cycles = @_cycles ||= Hashira::Coupling::Cycles.new(code, self)

  def pairs = edges.map(&:deconstruct).select { paired?(*it) }.map(&:sort).uniq

  def declarations(from, to) = noted(from, to, map.declared)

  def home(file) = @census.home(file)

  def sightings = @_sightings ||= Hashira::Coupling::Sightings.new(@project, @trees, @census).to_a

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

  def guarantees(from, to) = noted(from, to, map.pledges)

  def domain = edges.reject { aside?(it.from) || aside?(it.to) }

  def usage(package) = clients(package).reject { it.end_with?(@project.root) }.to_h { [it, map.usage[[it, package]]] }

  def constants(edge)
    names = map.usage[edge.deconstruct]
    names.reject { |name| names.any? { inside?(name, it) } }.sort
  end

  def metric(package)
    Hashira::Coupling::Metric.new(
      types: @census.types[package],
      afferent: clients(package).size,
      efferent: links[package].size
    )
  end

  def metrics = packages.to_h { [it, metric(it)] }

  def violations
    Hashira::Coupling::SdpCheck.new(links, metrics).violations.reject { cycles.tied?(*it) || paired?(*it) }
  end

  def weight(from, to) = evidence(from, to).size

  private

  def map
    @_map ||=
      Hashira::Coupling::EdgeMap.new(@census).tap do |edges|
        @trees.each { |file, tree| edges.record(@project.relative(file), file, tree) }
      end
  end

  def dependencies = map.dependencies

  def links
    @_links ||=
      packages.to_h do |package|
        [package, @census.test?(package) ? Set.new : dependencies[package].reject { aside?(it) }.to_set]
      end
  end

  def clients(package) = sources(links, package)

  def code = @_code ||= links.to_h { |from, tos| [from, tos.reject { navigation?(from, it) }.to_set] }

  def navigation?(from, to) = declares?(to, from) && evidence(from, to).all? { map.declared.key?(it) }

  def declares?(from, to) = declarations(from, to).any?

  def paired?(from, to) = declares?(from, to) && declares?(to, from)

  def noted(from, to, notes) = evidence(from, to).filter_map { notes[it] }

  def sources(targets, package) = packages.select { targets[it].include?(package) }.sort

  def aside?(package) = @census.aside?(package)

  def inside?(name, outer) = name.start_with?("#{outer}::") && @census.classes.include?(outer)
end
