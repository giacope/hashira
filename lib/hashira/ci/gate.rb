# frozen_string_literal: true

class Hashira::CI::Gate
  def initialize(findings, kinds, io: $stdout, error: $stderr)
    @findings = findings
    @kinds = kinds
    @io = io
    @error = error
  end

  def print = offending.empty? ? clean : failure

  def status = offending.empty? ? 0 : 1

  private

  def offending = @_offending ||= @findings.all.select { @kinds.include?(it.kind) }

  def failure
    offending.each { Hashira::Report::FindingLines.new(it, io: @io).print }
    verdict = "Gate FAILED: #{offending.size} finding(s) — #{tally(offending)}."
    @io.puts("\n#{verdict}")
    @error.puts(verdict)
  end

  def tally(offending)
    offending.group_by(&:kind).map { |kind, list| [kind, list.size] }
      .sort_by { |kind, size| [-size, kind] }.map { |kind, size| "#{kind} #{size}" }.join(", ")
  end

  def clean
    @io.puts("Gate OK: no findings of kind #{@kinds.join(", ")}.")
  end
end
