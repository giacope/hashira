# frozen_string_literal: true

class Hashira::GitLog
  GIT = %w[git --literal-pathspecs -c core.quotePath=false].freeze

  LOG = %w[log --no-renames --name-only --format=].freeze

  TOP = %w[rev-parse --show-toplevel].freeze

  def initialize(directories)
    @directories = directories
  end

  def counts = prefixes.map { within(it) }.reduce({}) { |found, more| found.merge(more) { |_, *seen| seen.max } }

  private

  def logged = @_logged ||= git(*LOG, "--", *roots).split("\n").map(&:strip).reject(&:empty?).tally

  def within(prefix) = logged.select { |path, _| path.start_with?(prefix) }.transform_keys { it.delete_prefix(prefix) }

  def prefixes = roots.map { it == top ? "" : "#{it.delete_prefix("#{top}/")}/" }

  def roots = @_roots ||= top.empty? ? [] : @directories.map { File.realpath(it).b }.select { inside?(it) }

  def inside?(root) = root == top || root.start_with?("#{top}/")

  def top = @_top ||= git(*TOP).strip

  def git(*arguments)
    IO.popen([*GIT, "-C", @directories.first, *arguments], err: File::NULL, binmode: true, &:read)
  rescue SystemCallError
    ""
  end
end
