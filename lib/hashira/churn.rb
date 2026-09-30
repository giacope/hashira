# frozen_string_literal: true

class Hashira::Churn
  FILES_THAT_DRIFT_APART = 2

  def self.build(directories) = new(Hashira::GitLog.new(directories).counts)

  def initialize(counts)
    @counts = counts
  end

  def history? = @counts.any?

  def hits(file) = @counts.fetch(file.b, 0)

  def hot?(members) = members.map(&:file).uniq.count { often?(it) } >= FILES_THAT_DRIFT_APART

  def often?(file) = hits(file) > typical

  private

  def typical = @_typical ||= @counts.values.sort.fetch((@counts.size - 1) / 2, 0)
end
