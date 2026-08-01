# frozen_string_literal: true

class Hashira::CI::FindingDiffReport
  def initialize(findings, io: $stdout)
    @findings = findings
    @io = io
  end

  def print(diff)
    introduced(diff.added).each { emit(it) }
    Hashira::CI::Improvement.new("Findings resolved", io: @io).print(diff.removed)
  end

  private

  def introduced(added) = added.filter_map { |signature| @findings.find { it.signature == signature } }

  def emit(finding)
    @io.puts("NEW FINDING:")
    Hashira::Report::FindingLines.new(finding, indent: "  ", io: @io).emit
  end
end
