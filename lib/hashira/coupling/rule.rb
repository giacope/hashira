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

  def framework = @_framework ||= project.framework

  def listing = @_listing ||= project.listing

  def metrics = @_metrics ||= graph.metrics

  def threshold(default) = @rules.limit(self.class::KIND, "threshold", default)

  def finding(name, detail, proof) = Hashira::Analysis::Finding.new(self.class::KIND, name, detail, proof)

  def sighted(package, detail, evidence, anchors = [])
    proof = Hashira::Analysis::Finding::Proof.new(evidence, anchors)
    finding(Hashira::Analysis::Finding::Name.new(package), detail, proof)
  end

  def between(from, to) = Hashira::Analysis::Finding::Name.new(from, ["#{from} -> #{to}"])

  def looped(key, cycles) = Hashira::Analysis::Finding::Name.new(key, [], [cycles.path(key)])
end
