# frozen_string_literal: true

class Hashira::GitLog
  GIT = %w[git --literal-pathspecs -c core.quotePath=false].freeze

  LOG = %w[log --full-history --no-renames --name-only --format=%x00].freeze

  TOP = %w[rev-parse --show-toplevel].freeze

  SHALLOW = %w[rev-parse --is-shallow-repository].freeze

  ENOUGH = 2

  def initialize(project)
    @project = project
  end

  def counts = changesets.flatten.tally

  def shallow? = (@_shallow ||= [git(*SHALLOW).strip == "true"]).first

  def deep? = !shallow? && changesets.size >= ENOUGH

  def changesets = @_changesets ||= commits.map { |paths| paths.map { shown(it) } }.reject(&:empty?)

  private

  def commits = git(*LOG, "--", *roots.values).split("\0").map { it.split("\n").map(&:strip).reject(&:empty?) }

  def shown(path)
    prefix, label = prefixes.find { |start, _| path.start_with?(start) }
    label + path.delete_prefix(prefix)
  end

  def prefixes
    @_prefixes ||=
      roots.map do |directory, root|
        [root == top ? "" : "#{root.delete_prefix("#{top}/")}/", @project.shown(directory).b]
      end
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
