# frozen_string_literal: true

class Hashira::Analysis::Rule
  def initialize(project, graph)
    @project = project
    @graph = graph
  end

  private

  attr_reader :project, :graph

  def metrics = @metrics ||= graph.metrics

  def finding(**attributes)
    Hashira::Analysis::Finding.new(kind: self.class::KIND, cycle: nil, **attributes)
  end
end
