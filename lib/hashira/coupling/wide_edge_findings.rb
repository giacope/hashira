# frozen_string_literal: true

require_relative "rule"

class Hashira::Coupling::WideEdgeFindings < Hashira::Coupling::Rule
  KIND = "wide_edge"

  WIDTH = 5

  def list
    graph.edges.select { wide?(it) }.map { entry(it) }
  end

  private

  def wide?(edge) = graph.constants(edge).size >= WIDTH

  def entry(edge)
    from, to = edge.deconstruct
    finding(
      package: from, digest: "#{from} -> #{to}", evidence: graph.evidence(from, to).to_a.first(4),
      detail: { from:, to:, constants: graph.constants(edge) }
    )
  end
end
