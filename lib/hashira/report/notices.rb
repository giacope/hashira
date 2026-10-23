# frozen_string_literal: true

class Hashira::Report::Notices
  ISSUES = "https://github.com/giacope/hashira/issues"

  FOLDERS = 3

  UNJUDGED = "layer_violation does not judge them"

  OPT_IN = "pass the directory, or --only a file, to analyse them"

  def initialize(io: $stderr)
    @io = io
  end

  def scanning(files, label) = progress("reading #{files} files in #{label}…")

  def finished(files, seconds) = progress("#{files} files in #{seconds}s")

  def churn(label, depth, coupling: false)
    unjudged = "; change_coupling cannot judge" if coupling
    @io.puts("hashira: #{history(depth)} for #{label} — hotspots are ranked by cost alone#{unjudged}")
  end

  def crashed(error)
    @io.puts("hashira: internal error — #{error.class}: #{error.message}")
    @io.puts("  at #{error.backtrace.first}")
    @io.puts("  this is a bug in hashira — please report it at #{ISSUES}")
  end

  def skipped(count, label, left)
    return if left.empty?
    counts = left.map { |reason, files| "#{files.size} #{reason}" }.join(" and ")
    @io.puts("hashira: analysed #{count} files in #{label}; skipped #{counts} (#{OPT_IN})")
  end

  def unlayered(loose, total)
    return if loose.empty?
    folders = loose.map { File.dirname(it).split("/").first(2).join("/") }.tally.max_by(FOLDERS, &:last)
    shown = folders.map { |folder, count| "#{folder} #{count}" }.join(", ")
    @io.puts("hashira: #{loose.size} of #{total} files sit in no layer (#{shown}) — #{UNJUDGED}")
  end

  def unparsed(count, sample)
    @io.puts("hashira: #{count} of the files did not parse — #{sample}")
  end

  private

  def history(depth)
    commits = depth.commits
    shallow = depth.shallow
    return "no git history" unless shallow || commits.positive?
    "#{shallow ? "shallow" : "too little"} git history (#{Hashira::Report::Count.new(commits, "commit")})"
  end

  def progress(line)
    @io.puts("hashira: #{line}") if @io.tty?
  end
end
