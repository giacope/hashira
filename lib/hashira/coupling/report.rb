# frozen_string_literal: true

require_relative "cycle"
require_relative "mixed_audience"
require_relative "echo"
require_relative "rule"
require_relative "imbalance"
require_relative "wide_edge"

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
