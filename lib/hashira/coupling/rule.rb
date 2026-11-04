# frozen_string_literal: true

class Hashira::Coupling::Rule
  def initialize(project, graph, rules, plan)
    @project = project
    @graph = graph
    @rules = rules
    @plan = plan
  end

  private

  attr_reader :project, :graph

  def paths = @_paths ||= project.paths

  def code = @_code ||= graph.code

  def packages = @_packages ||= graph.packages

  def edges = @_edges ||= graph.edges

  def lookup = @_lookup ||= graph.lookup

  def metrics = @_metrics ||= packages.to_h

  def threshold(default) = @rules.limit(self.class::KIND, "threshold", default)

  def finding(name, detail, proof) = Hashira::Analysis::Finding.new(self.class::KIND, name, detail, proof)

  def sighted(package, detail, evidence, anchors = [])
    proof = Hashira::Analysis::Finding::Proof.new(evidence, anchors)
    finding(Hashira::Analysis::Finding::Name.new(package), detail, proof)
  end

  def between(from, to) = Hashira::Analysis::Finding::Name.new(from, ["#{from} -> #{to}"])

  def looped(key, cycles) = Hashira::Analysis::Finding::Name.new(key, [], [cycles.path(key)])
end
