# frozen_string_literal: true

class Hashira::CI::RatchetReport
  def initialize(graph, findings, io: $stdout)
    @graph = graph
    @findings = findings
    @io = io
  end

  def print(edges, findings, tally)
    return unchanged(tally) if quiet?(edges, *findings)
    details(edges, findings)
    advice(edges, *findings)
  end

  def status(edges, findings) = quiet?(edges, *findings) ? 0 : verdict(edges, *findings)

  private

  def quiet?(*diffs) = diffs.all?(&:empty?)

  def unchanged(tally)
    @io.puts("Ratchet OK: #{tally}, unchanged.")
  end

  def verdict(*diffs) = diffs.any?(&:worse?) ? 1 : 3

  def details(edges, findings)
    Hashira::CI::EdgeChanges.new(@graph, io: @io).print(edges)
    findings.each { Hashira::CI::FindingChanges.new(@findings, io: @io).print(it) }
  end

  def advice(*diffs)
    return unless diffs.any?(&:worse?)
    @io.puts("\nRatchet FAILED. Either fix what regressed, or — if it is deliberate —")
    @io.puts("record the decision: update the baseline, or accept it with a reason.")
  end
end
