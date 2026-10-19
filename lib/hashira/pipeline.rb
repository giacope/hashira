# frozen_string_literal: true

require "prism"
require_relative "coupling/report"
require_relative "smells/report"

class Hashira::Pipeline
  ANALYZERS = %i[coupling complexity duplication smells].freeze

  STRUCTURAL = Hashira::Coupling::Report::RULES.map { it::KIND }.freeze

  SMELLS = (
    Hashira::Smells::Report::CHECKS.map { Hashira::Smells::Kind.new(it).to_s } + [Hashira::Smells::BoundarySprawl::KIND]
  ).sort.freeze

  KINDS = (STRUCTURAL + %w[complexity duplication fragmentation indirection] + SMELLS).sort.freeze

  def initialize(project, enabled: ANALYZERS, packaging: :auto, only: [])
    @project = project
    @enabled = enabled
    @packaging = packaging
    @only = only
  end

  attr_reader :project

  def verify
    boundaries.interpreted
    suppressions.directives
    self
  end

  def screened = @_screened ||= suppressions.screen(findings)

  def unparsed = parsed.unparsed

  def graph = coupling.graph

  def complexity = @_complexity ||= analyzed(:complexity, Hashira::Complexity::Scores, rules, parsed)

  def duplication = @_duplication ||= analyzed(:duplication, Hashira::Duplication::Clones, churn)

  def smells = @_smells ||= analyzed(:smells, Hashira::Smells::Report, boundaries, rules)

  def hotspots
    @_hotspots ||= Hashira::Hotspots::Rollup.new(complexity, duplication, churn) if complexity || duplication
  end

  def churn = @_churn ||= Hashira::Churn.build(@project)

  def enabled?(analyzer) = @enabled.include?(analyzer)

  def analyzed(name, kind, *extra)
    kind.new(@project, parsed.all, *extra) if enabled?(name)
  end

  def findings
    found = structural + listed(complexity) + listed(duplication) + listed(smells)
    focus.narrow(found.select { rules.enabled?(it.kind) })
  end

  def focus = @_focus ||= Hashira::Focus.new(@project, @only)

  private

  def rules = @project.rules

  def parsed = @_parsed ||= Hashira::Trees.new(@project)

  def boundaries = @_boundaries ||= Hashira::Boundaries.new(@project.boundaries, parsed.all, @project.home)

  def suppressions = @_suppressions ||= Hashira::Suppression::Suppressions.new(@project, parsed, KINDS)

  def coupling
    @_coupling ||= Hashira::Coupling::Report.new(@project, parsed.all, packaging: settle(@packaging), rules: rules)
  end

  def settle(packaging)
    return packaging unless packaging == :auto
    @project.rails? ? :namespace : :folder
  end

  def structural = enabled?(:coupling) ? coupling.findings : []

  def listed(analyzer) = analyzer ? analyzer.findings : []
end
