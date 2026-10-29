# frozen_string_literal: true

class Hashira::Outcome
  def initialize(project, trees, analyzers, judging)
    @project = project
    @trees = trees
    @analyzers = analyzers
    @judging = judging
  end

  def graph = @analyzers.graph

  def screened
    paths = @project.paths
    @_screened ||= suppressions(paths).screen(@judging.focus(paths).narrow(@judging.findings(@analyzers)))
  end

  def view(verdicts, layout) = Hashira::Report::View.new(@project, @judging.analyses(@analyzers), verdicts, layout)

  def notify(told, listing = @project.listing)
    @judging.history(told, @project.paths.to_s)
    listing.skipped(told)
    files = listing.to_a
    told.unlayered(@analyzers.unlayered(files), files.size)
    broken = @trees.unparsed
    told.unparsed(broken.size, broken.first(3).join(", ")) unless broken.empty?
  end

  private

  def suppressions(paths, checks = Hashira::Checks.new)
    Hashira::Suppression::Suppressions.new(paths, @trees, checks.to_a)
  end
end
