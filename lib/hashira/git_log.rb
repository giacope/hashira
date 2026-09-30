# frozen_string_literal: true

class Hashira::GitLog
  GIT = %w[git --literal-pathspecs -c core.quotePath=false].freeze

  LOG = %w[log --full-history --no-renames --name-only --format=].freeze

  TOP = %w[rev-parse --show-toplevel].freeze

  def initialize(project)
    @project = project
  end

  def counts = roots.map { |directory, root| within(directory, root) }.reduce({}, :merge)

  private

  def logged = @_logged ||= git(*LOG, "--", *roots.values).split("\n").map(&:strip).reject(&:empty?).tally

  def within(directory, root)
    prefix = root == top ? "" : "#{root.delete_prefix("#{top}/")}/"
    shown = @project.shown(directory).b
    logged.select { |path, _| path.start_with?(prefix) }.transform_keys { shown + it.delete_prefix(prefix) }
  end

  def roots = @_roots ||= @project.directories.to_h { [it, File.realpath(it).b] }.select { |_, root| inside?(root) }

  def inside?(root) = root == top || root.start_with?("#{top}/")

  def top = @_top ||= git(*TOP).strip

  def git(*arguments)
    IO.popen([*GIT, "-C", @project.directories.first, *arguments], err: File::NULL, binmode: true, &:read)
  rescue SystemCallError
    ""
  end
end
