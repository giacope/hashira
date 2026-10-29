# frozen_string_literal: true

class Hashira::CI::FindingChanges
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

  def introduced(added) = added.flat_map { |signature| signed(signature) }

  def aggravated(worsened)
    worsened.flat_map { |signature, before, after| signed(signature).map { [it, before, after] } }
  end

  def signed(signature) = signatures.fetch(signature, []).first(1)

  def signatures = @_signatures ||= @findings.group_by { it.scored.keys.fetch(0) }

  def regressed(finding, before, after)
    @io.puts("WORSE FINDING (was #{before}, now #{after}):")
    Hashira::Report::FindingLines.new(finding, indent: "  ", io: @io).emit
  end

  def emit(finding)
    @io.puts("NEW FINDING:")
    Hashira::Report::FindingLines.new(finding, indent: "  ", io: @io).emit
  end
end
