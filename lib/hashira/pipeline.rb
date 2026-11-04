# frozen_string_literal: true

require "prism"
require_relative "checks"

class Hashira::Pipeline
  def self.build(
    project, rules = Hashira::Config::Rules.new({}), layers = Hashira::Config::Layers.new([]),
    selection = Hashira::Selection.new
  )
    trees = selection.trees(project.listing)
    history = Hashira::GitLog.new(project.paths)
    analyzers = Hashira::Analyzers.build(project, trees, rules, Hashira::Plan.new(layers, history, selection))
    outcome = Hashira::Outcome.new(project, trees, analyzers, Hashira::Judging.new(rules, selection, history))
    new(outcome, Hashira::Coverage.new(rules, selection, history, project.paths), project, trees)
  end

  def initialize(outcome, coverage, project, trees)
    @outcome = outcome
    @coverage = coverage
    @project = project
    @trees = trees
  end

  def verify(checks = Hashira::Checks.new)
    @project.boundaries(@trees.all).interpreted
    Hashira::Suppression::Suppressions.new(@project.paths, @trees, checks.to_a).directives
    self
  end

  def call(runner) = runner.call(@outcome, @coverage)

  def finished(told, seconds, listing = @project.listing) = told.finished(listing.to_a.size, seconds)
end
