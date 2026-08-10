# frozen_string_literal: true

class Hashira::Churn
  LOG = %w[log --no-renames --name-only --format=].freeze
  SITES_THAT_DRIFT_APART = 2

  def self.scan(directory) = new(tally(read(directory)))

  def self.read(directory)
    IO.popen(["git", "-C", directory, *LOG], err: File::NULL, &:read)
  rescue SystemCallError
    ""
  end

  def self.tally(output) = output.split("\n").map(&:strip).reject(&:empty?).tally

  def initialize(counts)
    @counts = counts
  end

  def history? = @counts.any?

  def hits(file) = @counts.select { |path, _| path.end_with?(file) }.values.max || 0

  def hot?(members) = changing(members) >= SITES_THAT_DRIFT_APART

  def changing(members) = members.count { |member| hits(member.file).positive? }
end
