# frozen_string_literal: true

class Hashira::Report::Notices
  ISSUES = "https://github.com/giacope/hashira/issues"

  OPT_IN = "pass the directory, or --only a file, to analyse them"

  def initialize(io: $stderr)
    @io = io
  end

  def scanning(files, label) = progress("reading #{files} files in #{label}…")

  def finished(files, seconds) = progress("#{files} files in #{seconds}s")

  def churn(label)
    @io.puts("hashira: no git history for #{label} — hotspots are ranked by cost alone")
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

  def unparsed(count, sample)
    @io.puts("hashira: #{count} of the files did not parse — #{sample}")
  end

  private

  def progress(line)
    @io.puts("hashira: #{line}") if @io.tty?
  end
end
