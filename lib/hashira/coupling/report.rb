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

  def self.build(project, trees, rules, plan)
    new(project, rules, plan, Hashira::Coupling::Lazy.new { Hashira::Coupling::Graph.build(project, trees) })
  end

  def initialize(project, rules, plan, graph)
    @project = project
    @rules = rules
    @plan = plan
    @graph = graph
  end

  def graph = @graph.call

  def findings
    return [] unless runs?
    RULES.select { @rules.enabled?(it::KIND) }.flat_map { it.new(@project, graph, @rules, @plan).list }
  end

  def shown = runs? ? [graph] : []

  def unlayered(files) = @plan.unlayered(files) { graph.code }

  private

  def runs? = @plan.enabled?(ANALYZER)
end
