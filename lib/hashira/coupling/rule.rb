# frozen_string_literal: true

class Hashira::Coupling::Rule
  def initialize(project, graph, rules)
    @project = project
    @graph = graph
    @rules = rules
  end

  private

  attr_reader :project, :graph

  def metrics = @_metrics ||= graph.metrics

  def threshold(default) = @rules.threshold(self.class::KIND, default)

  def finding(**attributes)
    Hashira::Analysis::Finding.new(kind: self.class::KIND, cycle: nil, **attributes)
  end
end
