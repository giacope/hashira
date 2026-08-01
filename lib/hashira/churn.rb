# frozen_string_literal: true

class Hashira::Churn
  LOG = "git log --name-only --format= 2>/dev/null"
  SITES_THAT_DRIFT_APART = 2

  def self.scan = new(tally(`#{LOG}`))

  def self.tally(output) = output.split("\n").map(&:strip).reject(&:empty?).tally

  def initialize(counts)
    @counts = counts
  end

  def hits(file) = @counts.select { |path, _| path.end_with?(file) }.values.max || 0

  def hot?(members) = changing(members) >= SITES_THAT_DRIFT_APART

  def changing(members) = members.count { |member| hits(member.file).positive? }
end
