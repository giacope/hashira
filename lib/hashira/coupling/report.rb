# frozen_string_literal: true

require_relative "manifest"
require_relative "change_coupling"
require_relative "cycle"
require_relative "dead_code"
require_relative "mixed_audience"
require_relative "echo"
require_relative "rule"
require_relative "imbalance"
require_relative "layering"
require_relative "navigation"
require_relative "wide_edge"

class Hashira::Coupling::Report
  RULES = Hashira::Coupling::Rule.subclasses.sort_by(&:name).freeze

  ANALYZER = :coupling

  def initialize(project, trees, rules, plan)
    @project = project
    @trees = trees
    @rules = rules
    @plan = plan
  end

  def graph = @_graph ||= Hashira::Coupling::Graph.new(@project, @trees, census)

  def findings
    return [] unless runs?
    RULES.select { @rules.enabled?(it::KIND) }.flat_map { it.new(@project, graph, @rules, @plan).list }
  end

  def shown = runs? ? [graph] : []

  def unlayered(files) = @plan.unlayered(files) { graph.census }

  private

  def runs? = @plan.enabled?(ANALYZER)

  def census = Hashira::Coupling::Census.new(@project, @trees, packaging: framework.packaging)

  def framework = @_framework ||= @project.framework
end
