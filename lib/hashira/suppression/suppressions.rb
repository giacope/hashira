# frozen_string_literal: true

class Hashira::Suppression::Suppressions
  Screened = Data.define(:kept, :suppressed, :unused)

  CLEAR = Screened.new(kept: [], suppressed: [], unused: [])

  def initialize(project, trees, kinds)
    @project = project
    @trees = trees
    @kinds = kinds
  end

  def directives = @_directives ||= @trees.comments.flat_map { |path, comments| read(path, comments) }

  def read(path, comments)
    Hashira::Suppression::Directives.new(@project.relative(path), comments, @trees.lines(path), @kinds).to_a
  end

  def screen(findings)
    judged = findings.map { Hashira::Suppression::Silence.new(it, directives).verdict }
    used = judged.flat_map(&:last)
    Screened.new(kept: judged.filter_map(&:first), suppressed: judged.flat_map { it[1] }, unused: directives - used)
  end
end
