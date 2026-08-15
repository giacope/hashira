# frozen_string_literal: true

class Hashira::Complexity::Scores
  THRESHOLD = 10

  def initialize(project, trees)
    @project = project
    @trees = trees
  end

  def ranked = scores.sort_by { -it.cognitive }

  def classes = Hashira::Complexity::Rollup.new(scores).classes.sort_by { -it.cognitive }

  def findings = flagged.map { Hashira::Complexity::MethodFinding.new(it).to_finding }

  private

  def scores = @_scores ||= @trees.flat_map { |path, tree| harvest(path, tree) }

  def flagged = ranked.select { it.cognitive >= THRESHOLD }

  def harvest(path, tree)
    relative = @project.relative(path)
    sites(tree).map { |full, node| score(relative, full, node) }
  end

  def sites(tree)
    found = []
    Hashira::Analysis::TypeWalk.each(tree) do |type, full|
      Hashira::Analysis::Syntax.direct(type).each { found << [full, it] }
    end
    found
  end

  def score(relative, full, node)
    Hashira::Complexity::MethodScore.new(
      subject: subject(full, node), file: relative, line: node.location.start_line,
      **tallies(Hashira::Complexity::CognitiveScore.new(node))
    )
  end

  def tallies(score) = { cognitive: score.total, calls: score.calls, increments: score.increments }

  def subject(full, node) = "#{full.join("::")}#{node.receiver ? "." : "#"}#{node.name}"
end
