# frozen_string_literal: true

class Hashira::Churn
  SITES_THAT_DRIFT_APART = 2

  def self.build(directory) = new(Hashira::GitLog.new(directory).counts)

  def initialize(counts)
    @counts = counts
  end

  def history? = @counts.any?

  def hits(file) = @counts.select { |path, _| path.end_with?(file) }.values.max || 0

  def hot?(members) = changing(members) >= SITES_THAT_DRIFT_APART

  def changing(members) = members.count { |member| hits(member.file).positive? }
end
