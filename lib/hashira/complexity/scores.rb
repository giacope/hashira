# frozen_string_literal: true

class Hashira::Complexity::Scores
  THRESHOLD = 10

  KIND = Hashira::Complexity::MethodFinding::KIND

  def initialize(project, trees, rules)
    @project = project
    @trees = trees
    @rules = rules
  end

  def ranked = scores.sort_by { -it.cognitive }

  def classes = Hashira::Complexity::Rollup.new(scores).classes.sort_by { -it.cognitive }

  def lists = { methods: ranked, classes: }

  def findings = flagged.map { Hashira::Complexity::MethodFinding.new(it).to_finding } + indirection.findings

  def indirection = Hashira::Complexity::Indirection.new(sites, @trees.values, @rules)

  def sites = @_sites ||= @trees.flat_map { |path, tree| harvest(@project.relative(path), tree) }

  private

  def scores = @_scores ||= sites.map { |relative, site| score(relative, site) }

  def flagged = ranked.select { it.cognitive >= @rules.threshold(KIND, THRESHOLD) }

  def harvest(relative, tree) = Hashira::Complexity::Sites.new(tree).to_enum(:each).map { [relative, it] }

  def recursion = @_recursion ||= Hashira::Complexity::Recursion.new(sites.map(&:last))

  def score(relative, site)
    node = site.node
    Hashira::Complexity::MethodScore.new(
      subject: site.subject, file: relative, line: node.location.start_line,
      **Hashira::Complexity::CognitiveScore.new(node).tallies(recursion.increments(site))
    )
  end
end
