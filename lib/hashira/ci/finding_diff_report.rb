# frozen_string_literal: true

class Hashira::CI::FindingDiffReport
  def initialize(findings, io: $stdout)
    @findings = findings
    @io = io
  end

  def print(diff)
    introduced(diff.added).each { emit(it) }
    aggravated(diff.worsened).each { |finding, before, after| regressed(finding, before, after) }
    Hashira::CI::Improvement.new("Findings resolved", io: @io).print(diff.removed)
  end

  private

  def introduced(added) = added.filter_map { |signature| @findings.find { it.signature == signature } }

  def aggravated(worsened)
    worsened.map { |signature, before, after| [@findings.find { it.signature == signature }, before, after] }
  end

  def regressed(finding, before, after)
    @io.puts("WORSE FINDING (was #{before}, now #{after}):")
    Hashira::Report::FindingLines.new(finding, indent: "  ", io: @io).emit
  end

  def emit(finding)
    @io.puts("NEW FINDING:")
    Hashira::Report::FindingLines.new(finding, indent: "  ", io: @io).emit
  end
end
