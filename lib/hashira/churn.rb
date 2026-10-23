# frozen_string_literal: true

require_relative "git_log"

class Hashira::Churn
  FILES_THAT_DRIFT_APART = 2

  Depth = Data.define(:commits, :shallow, :deep)

  DEEP = Depth.new(commits: Hashira::GitLog::ENOUGH, shallow: false, deep: true)

  def self.build(project)
    history = project.history
    depth = Depth.new(commits: history.changesets.size, shallow: history.shallow?, deep: history.deep?)
    new(depth.shallow ? {} : history.counts, depth)
  end

  def initialize(counts, depth = DEEP)
    @counts = counts
    @depth = depth
  end

  attr_reader :depth

  def history? = @depth.deep

  def hits(file) = @counts.fetch(file.b, 0)

  def hot?(members) = members.map(&:file).uniq.count { often?(it) } >= FILES_THAT_DRIFT_APART

  def often?(file) = hits(file) > typical

  private

  def typical = @_typical ||= @counts.values.sort.fetch((@counts.size - 1) / 2, 0)
end
