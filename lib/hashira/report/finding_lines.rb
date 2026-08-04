# frozen_string_literal: true

class Hashira::Report::FindingLines
  SAMPLE = 4

  def initialize(finding, indent: "", io: $stdout)
    @finding = finding
    @indent = indent
    @io = io
  end

  def print
    @io.puts("#{@indent}#{@finding.kind}: #{Hashira::Report::Phrases.message(@finding)}")
    @finding.evidence.first(SAMPLE).each { @io.puts("#{@indent}    · #{it}") }
  end

  def emit
    print
    overflow = @finding.evidence.size - SAMPLE
    @io.puts("#{@indent}    · … (#{overflow} more)") if overflow.positive?
  end
end
