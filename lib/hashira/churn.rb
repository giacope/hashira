# frozen_string_literal: true

require_relative "git_log"

class Hashira::Churn
  FILES_THAT_DRIFT_APART = 2

  class Depth
    def initialize(commits:, shallow:, deep:)
      @commits = commits
      @shallow = shallow
      @deep = deep
    end

    def self.build(history) = new(commits: history.changesets.size, shallow: history.shallow?, deep: history.deep?)

    def deep? = @deep

    def to_s
      return "no git history" unless @shallow || @commits.positive?
      "#{@shallow ? "shallow" : "too little"} git history (#{Hashira::Prose::Count.new(@commits, "commit")})"
    end
  end

  DEEP = Depth.new(commits: 2, shallow: false, deep: true)

  def self.build(history) = new(history.shallow? ? {} : history.counts, Depth.build(history))

  def initialize(counts, depth = DEEP)
    @counts = counts
    @depth = depth
  end

  def history? = @depth.deep?

  def hits(file) = @counts.fetch(file.b, 0)

  def hot?(members) = members.map(&:file).uniq.count { often?(it) } >= FILES_THAT_DRIFT_APART

  private

  def often?(file) = hits(file) > typical

  def typical = @_typical ||= @counts.values.sort.fetch((@counts.size - 1) / 2, 0)
end
