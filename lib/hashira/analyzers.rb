# frozen_string_literal: true

class Hashira::Analyzers
  def self.build(project, trees, rules, plan)
    all = trees.all
    paths = project.paths
    new(
      Hashira::Coupling::Report.build(project, all, rules, plan),
      [Hashira::Complexity::Scores.new(paths, all, rules, trees)].select { plan.enabled?(:complexity) },
      [Hashira::Duplication::Clones.new(paths, all)].select { plan.enabled?(:duplication) },
      [Hashira::Smells::Survey.new(Hashira::Smells::Census.new(project, all), project.boundaries(all), rules)]
        .select { plan.enabled?(:smells) }
    )
  end

  def initialize(coupling, complexity, duplication, smells)
    @coupling = coupling
    @complexity = complexity
    @duplication = duplication
    @smells = smells
  end

  def graph = @coupling.graph

  def findings(churn)
    @coupling.findings + @complexity.flat_map(&:findings) + @duplication.flat_map { it.findings(churn) } +
      @smells.flat_map(&:findings)
  end

  def analyses(churn)
    Hashira::Report::View::Analyses.new(@coupling.shown, @complexity, @duplication, hotspots(churn))
  end

  def unlayered(files) = @coupling.unlayered(files)

  private

  def hotspots(churn)
    [Hashira::Hotspots::Rollup.new(@complexity, @duplication, churn)].reject { [@complexity, @duplication].none?(&:any?) }
  end
end
