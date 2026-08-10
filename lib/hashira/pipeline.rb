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
    @trees = project.files.to_h { [it, parse(it)] }
    @coupling = Hashira::Coupling::Report.new(project, @trees, packaging: settle(packaging))
  end

  attr_reader :project

  def graph = @coupling.graph

  def complexity
    @complexity ||= Hashira::Complexity::Scores.new(@project, @trees) if enabled?(:complexity)
  end

  def duplication
    @duplication ||= Hashira::Duplication::Clones.new(@project, @trees, churn) if enabled?(:duplication)
  end

  def smells
    @smells ||= Hashira::Smells::Report.new(@project, @trees) if enabled?(:smells)
  end

  def hotspots
    @hotspots ||= Hashira::Hotspots::Rollup.new(complexity, duplication, churn) if complexity || duplication
  end

  def churn = @churn ||= Hashira::Churn.scan(@project.directories.first)

  def enabled?(analyzer) = @enabled.include?(analyzer)

  def findings = structural + listed(complexity) + listed(duplication) + listed(smells)

  private

  def settle(packaging)
    return packaging unless packaging == :auto
    @project.rails? ? :namespace : :folder
  end

  def structural = enabled?(:coupling) ? @coupling.findings : []

  def listed(analyzer) = analyzer ? analyzer.findings : []

  def parse(path)
    Prism.parse_file(path).value
  rescue SystemCallError => error
    raise(Hashira::Error, "cannot read #{path} (#{error.message})")
  end
end
