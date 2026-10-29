# frozen_string_literal: true

class Hashira::Complexity::Scores
  THRESHOLD = 10

  KIND = "complexity"

  def initialize(project, trees, rules, parsed)
    @project = project
    @trees = trees
    @rules = rules
    @parsed = parsed
  end

  def ranked = scores.sort_by { -it.cognitive }

  def classes = Hashira::Complexity::Rollup.new(scores).classes.sort_by { -it.cognitive }

  def to_h = { methods: ranked, classes: }

  def findings
    flagged.map(&:finding) +
      Hashira::Complexity::Indirection.new(sites, @trees.values, @rules).findings +
      Hashira::Complexity::Fragmentation.new(sites, notes, @trees.values, @rules).findings
  end

  private

  def notes
    comments = @parsed.comments
    @trees.keys.to_h { [@project.relative(it), Hashira::Complexity::Notes.new(@parsed, it, comments.fetch(it))] }
  end

  def sites = @_sites ||= @trees.flat_map { |path, tree| harvest(@project.relative(path), tree) }

  def scores = @_scores ||= scored(Hashira::Complexity::Recursion.new(sites))

  def flagged = ranked.select { it.cognitive >= @rules.threshold(KIND, THRESHOLD) }

  def harvest(relative, tree)
    Hashira::Complexity::Sites.new(tree).to_enum(:each).map { |owner, node| [relative, owner, node] }
  end

  def scored(recursion)
    sites.map do |relative, owner, node|
      extra = recursion.increments(owner, node)
      Hashira::Complexity::CognitiveScore.new(node).score(owner.subject(node), relative, extra)
    end
  end
end
