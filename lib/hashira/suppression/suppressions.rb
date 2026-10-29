# frozen_string_literal: true

class Hashira::Suppression::Suppressions
  class Screened
    def initialize(kept, suppressed, unused)
      @kept = kept
      @suppressed = suppressed
      @unused = unused
    end

    def to_a = [@kept, @suppressed, @unused]
  end

  CLEAR = Screened.new([], [], [])

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
    judged = findings.map { it.silenced(directives) }
    used = judged.flat_map(&:last)
    Screened.new(judged.flat_map(&:first), judged.flat_map { it[1] }, directives - used)
  end
end
