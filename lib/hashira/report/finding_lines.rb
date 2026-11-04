# frozen_string_literal: true

class Hashira::Report::FindingLines
  SAMPLE = 4

  def initialize(finding, indent: "", io: $stdout)
    @finding = finding
    @indent = indent
    @io = io
  end

  def print
    headline, *evidence = lines
    @io.puts("#{@indent}#{headline}")
    evidence.first(SAMPLE).each { @io.puts("#{@indent}    · #{it}") }
  end

  def emit
    print
    overflow = lines.size - 1 - SAMPLE
    @io.puts("#{@indent}    · … (#{overflow} more)") if overflow.positive?
  end

  private

  def lines = @_lines ||= @finding.to_a
end
