# frozen_string_literal: true

require "prism"
require_relative "checks"

class Hashira::Pipeline
  HISTORIC = "change_coupling"

  private_constant :HISTORIC

  def initialize(project, enabled: Hashira::Checks.new.analyzers, packaging: :auto, only: [])
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

  def notify(told)
    history(told)
    told.skipped(*@project.scope)
    told.unlayered(unlayered, size)
    broken = unparsed
    told.unparsed(broken.size, broken.first(3).join(", ")) unless broken.empty?
  end

  def history(told)
    return if churn.history?
    told.churn(@project.label, depth, coupling: rules.enabled?(HISTORIC))
  end

  def targets(home) = @project.directories.map { home.relative(it) }

  def checks?(kind) = rules.enabled?(kind) && (kind != HISTORIC || churn.history?)

  def unjudged?(kind) = rules.enabled?(kind) && !checks?(kind)

  def depth = @_depth ||= Hashira::Churn::Depth.build(@project.history)

  def size = @project.files.size

  def unlayered
    layers = @project.layers
    layers.names.any? && enabled?(:coupling) ? graph.census.unlayered(layers, @project.files) : []
  end

  def graph = coupling.graph

  def complexity = @_complexity ||= analyzed(:complexity, Hashira::Complexity::Scores, rules, parsed)

  def duplication = @_duplication ||= analyzed(:duplication, Hashira::Duplication::Clones, churn)

  def smells
    @_smells ||= (smelled if enabled?(:smells))
  end

  def hotspots
    @_hotspots ||= Hashira::Hotspots::Rollup.new(complexity, duplication, churn) if complexity || duplication
  end

  def churn = @_churn ||= Hashira::Churn.build(@project.history)

  def enabled?(analyzer) = @enabled.include?(analyzer)

  def smelled = Hashira::Smells::Report.new(Hashira::Smells::Census.new(@project, parsed.all).types, boundaries, rules)

  def analyzed(name, kind, *extra)
    kind.new(@project, parsed.all, *extra) if enabled?(name)
  end

  def findings
    found = structural + listed(complexity) + listed(duplication) + listed(smells)
    focus.narrow(found.select { it.of?(enabled) })
  end

  def focus = @_focus ||= Hashira::Focus.new(@project, @only)

  private

  def rules = @project.rules

  def parsed = @_parsed ||= Hashira::Trees.new(@project, @only)

  def boundaries = @_boundaries ||= Hashira::Boundaries.new(@project.boundaries, parsed.all, @project.home)

  def suppressions = @_suppressions ||= Hashira::Suppression::Suppressions.new(@project, parsed, kinds)

  def kinds(checks = Hashira::Checks.new) = checks.to_a

  def enabled(checks = Hashira::Checks.new) = @_enabled ||= checks.select { rules.enabled?(it) }

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
