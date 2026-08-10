# frozen_string_literal: true

require "prism"
require_relative "coupling/report"
require_relative "smells/report"

class Hashira::Pipeline
  ANALYZERS = %i[coupling complexity duplication smells].freeze

  STRUCTURAL = Hashira::Coupling::Report::RULES.map { it::KIND }.freeze

  SMELLS = (
    Hashira::Smells::Report::CHECKS.map(&:kind) + [Hashira::Smells::BoundarySprawl::KIND]
  ).sort.freeze

  def initialize(project, enabled: ANALYZERS, packaging: :auto)
    @project = project
    @enabled = enabled
    @parsed = Hashira::Trees.new(project)
    @coupling = Hashira::Coupling::Report.new(project, @parsed.all, packaging: settle(packaging))
  end

  attr_reader :project

  def unparsed = @parsed.unparsed

  def graph = @coupling.graph

  def complexity = @complexity ||= analyzed(:complexity, Hashira::Complexity::Scores)

  def duplication = @duplication ||= analyzed(:duplication, Hashira::Duplication::Clones, churn)

  def smells = @smells ||= analyzed(:smells, Hashira::Smells::Report)

  def hotspots
    @hotspots ||= Hashira::Hotspots::Rollup.new(complexity, duplication, churn) if complexity || duplication
  end

  def churn = @churn ||= Hashira::Churn.scan(@project.directories.first)

  def enabled?(analyzer) = @enabled.include?(analyzer)

  def analyzed(name, kind, *extra)
    kind.new(@project, @parsed.all, *extra) if enabled?(name)
  end

  def findings = structural + listed(complexity) + listed(duplication) + listed(smells)

  private

  def settle(packaging)
    return packaging unless packaging == :auto
    @project.rails? ? :namespace : :folder
  end

  def structural = enabled?(:coupling) ? @coupling.findings : []

  def listed(analyzer) = analyzer ? analyzer.findings : []
end
