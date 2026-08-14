# frozen_string_literal: true

class Hashira::GitLog
  LOG = %w[log --no-renames --name-only --format=].freeze

  def initialize(directory)
    @directory = directory
  end

  def counts = output.split("\n").map(&:strip).reject(&:empty?).tally

  private

  def output
    IO.popen(["git", "-C", @directory, *LOG], err: File::NULL, &:read)
  rescue SystemCallError
    ""
  end
end
