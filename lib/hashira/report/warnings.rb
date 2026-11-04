# frozen_string_literal: true

class Hashira::Report::Warnings
  FOLDERS = 3

  UNJUDGED = "layer_violation does not judge them"

  OPT_IN = "pass the directory, or --only a file, to analyse them"

  REASONS = { template: "in project templates" }.freeze

  def initialize(io: $stderr)
    @io = io
  end

  def churn(label, history, coupling: false)
    unjudged = "; change_coupling cannot judge" if coupling
    @io.puts("hashira: #{history} for #{label} — hotspots are ranked by cost alone#{unjudged}")
  end

  def skipped(count, label, left)
    return if left.empty?
    counts = left.map { |reason, files| "#{files.size} #{REASONS.fetch(reason, reason)}" }.join(" and ")
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
end
