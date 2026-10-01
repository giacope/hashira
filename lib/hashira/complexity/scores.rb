# frozen_string_literal: true

class Hashira::Complexity::Scores
  THRESHOLD = 10

  def initialize(project, trees)
    @project = project
    @trees = trees
  end

  def ranked = scores.sort_by { -it.cognitive }

  def classes = Hashira::Complexity::Rollup.new(scores).classes.sort_by { -it.cognitive }

  def lists = { methods: ranked, classes: }

  def findings = flagged.map { Hashira::Complexity::MethodFinding.new(it).to_finding }

  private

  def scores = @_scores ||= @trees.flat_map { |path, tree| harvest(path, tree) }

  def flagged = ranked.select { it.cognitive >= THRESHOLD }

  def harvest(path, tree)
    relative = @project.relative(path)
    Hashira::Complexity::Sites.new(tree).to_enum(:each).map { score(relative, it) }
  end

  def score(relative, site)
    node = site.node
    Hashira::Complexity::MethodScore.new(
      subject: site.subject, file: relative, line: node.location.start_line,
      **tallies(Hashira::Complexity::CognitiveScore.new(node))
    )
  end

  def tallies(score) = { cognitive: score.total, calls: score.calls, increments: score.increments }
end
