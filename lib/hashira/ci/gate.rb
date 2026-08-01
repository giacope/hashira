# frozen_string_literal: true

class Hashira::CI::Gate
  def initialize(findings, kinds, io: $stdout)
    @findings = findings
    @kinds = kinds
    @io = io
  end

  def check
    offending = @findings.all.select { @kinds.include?(it.kind) }
    offending.empty? ? clean : failure(offending)
  end

  private

  def failure(offending)
    offending.each { Hashira::Report::FindingLines.new(it, io: @io).print }
    @io.puts("\nGate FAILED: #{offending.size} finding(s) of kind #{@kinds.join(", ")}.")
    1
  end

  def clean
    @io.puts("Gate OK: no findings of kind #{@kinds.join(", ")}.")
    0
  end
end
