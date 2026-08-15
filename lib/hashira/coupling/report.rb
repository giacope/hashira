# frozen_string_literal: true

require_relative "cycle_findings"
require_relative "mixed_audience_findings"
require_relative "roll_call_findings"
require_relative "rule"
require_relative "sdp_violation_findings"
require_relative "wide_edge_findings"

class Hashira::Coupling::Report
  RULES = Hashira::Coupling::Rule.subclasses.sort_by(&:name).freeze

  def initialize(project, trees, packaging:)
    @project = project
    @trees = trees
    @packaging = packaging
  end

  def graph = @_graph ||= Hashira::Coupling::Graph.new(@project, @trees, census)

  def findings = RULES.flat_map { it.new(@project, graph).list }

  private

  def census = Hashira::Coupling::Census.new(@project, @trees, packaging: @packaging)
end
