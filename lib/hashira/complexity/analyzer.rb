# frozen_string_literal: true

class Hashira::Complexity::Analyzer
  THRESHOLD = 10

  def initialize(project, trees)
    @project = project
    @scores = trees.flat_map { |path, tree| harvest(path, tree) }
  end

  def methods = @scores.sort_by { -it.cognitive }

  def classes = Hashira::Complexity::Rollup.new(@scores).classes.sort_by { -it.cognitive }

  def findings = flagged.map { Hashira::Complexity::MethodFinding.new(it).to_finding }

  private

  def flagged = methods.select { it.cognitive >= THRESHOLD }

  def harvest(path, tree)
    rel = @project.relative(path)
    sites(tree).map { |full, node| score(rel, full, node) }
  end

  def sites(tree)
    found = []
    Hashira::Analysis::TypeWalk.each(tree) do |type_node, full|
      Hashira::Analysis::Syntax.direct(type_node).each { found << [full, it] }
    end
    found
  end

  def score(rel, full, node)
    score = Hashira::Complexity::CognitiveScore.new(node)
    Hashira::Complexity::MethodScore.new(
      subject: subject(full, node), file: rel, line: node.location.start_line,
      cognitive: score.total, calls: score.calls, increments: score.increments
    )
  end

  def subject(full, node) = "#{full.join("::")}#{node.receiver ? "." : "#"}#{node.name}"
end
