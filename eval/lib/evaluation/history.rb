# frozen_string_literal: true

class Evaluation::History
  AUTHOR = %w[-c user.email=eval@example.com -c user.name=eval -c commit.gpgsign=false].freeze

  def initialize(root)
    @root = root
  end

  def replay(commits)
    return if commits.empty?
    git("init", "-q")
    commits.each_with_index { |paths, index| commit(paths, index) }
  end

  private

  def commit(paths, index)
    paths.each { File.write(File.join(@root, it), "# change #{index}\n", mode: "a") }
    git("add", *paths)
    git(*AUTHOR, "commit", "-qm", "change #{index}")
  end

  def git(*) = system("git", "-C", @root, *, exception: true)
end
