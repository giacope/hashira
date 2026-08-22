# frozen_string_literal: true

require "prism"
require_relative "plan"

class Hashira::Pipeline
  def initialize(project, plan = Hashira::Plan::WHOLE)
    @project = project
    @plan = plan
  end

  attr_reader :project

  def unparsed = parsed.unparsed

  def graph = coupling.graph

  def complexity = @_complexity ||= analyzed(:complexity, Hashira::Complexity::Scores)

  def duplication = @_duplication ||= analyzed(:duplication, Hashira::Duplication::Clones, churn)

  def smells = @_smells ||= analyzed(:smells, Hashira::Smells::Report, @plan.constraints)

  def hotspots
    @_hotspots ||= Hashira::Hotspots::Rollup.new(complexity, duplication, churn) if complexity || duplication
  end

  def churn = @_churn ||= Hashira::Churn.build(@project.directories.first)

  def enabled?(analyzer) = @plan.enabled?(analyzer)

  def analyzed(name, kind, *extra)
    kind.new(@project, parsed.all, *extra) if enabled?(name)
  end

  def findings = focus.narrow(structural + listed(complexity) + listed(duplication) + listed(smells))

  def focus = @_focus ||= Hashira::Focus.new(@project, @plan.only)

  def snapshot = @_snapshot ||= Hashira::Snapshot.new(@project)

  def declared = @plan.constraints.identity

  private

  def parsed = @_parsed ||= Hashira::Trees.new(snapshot).tap { vetted(it.all) }

  def vetted(trees)
    stop = @plan.constraints.trouble(trees)
    raise(Hashira::Error, stop) if stop
  end

  def coupling
    @_coupling ||= Hashira::Coupling::Report.new(@project, parsed.all, packaging: @plan.settled(@project))
  end

  def structural = enabled?(:coupling) ? coupling.findings : []

  def listed(analyzer) = analyzer ? analyzer.findings : []
end
