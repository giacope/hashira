# frozen_string_literal: true

class Hashira::CI::RatchetReport
  def initialize(graph, findings, io: $stdout)
    @graph = graph
    @findings = findings
    @io = io
  end

  def print(edges, findings, tally)
    return unchanged(tally) if quiet?(edges, findings)
    details(edges, findings)
    advice(edges, findings)
    verdict(edges, findings)
  end

  private

  def quiet?(*diffs) = diffs.compact.all?(&:empty?)

  def unchanged(tally)
    @io.puts("Ratchet OK: #{tally}, unchanged.")
    Hashira::CI::Status::CLEAN
  end

  def verdict(*diffs) = diffs.compact.any?(&:worse?) ? Hashira::CI::Status::WORSE : Hashira::CI::Status::BETTER

  def details(edges, findings)
    Hashira::CI::EdgeDiffReport.new(@graph, io: @io).print(edges)
    Hashira::CI::FindingDiffReport.new(@findings, io: @io).print(findings) if findings
  end

  def advice(*diffs)
    return unless diffs.compact.any?(&:worse?)
    @io.puts("\nRatchet FAILED. Either fix what regressed, or — if it is deliberate —")
    @io.puts("record the decision: update the baseline, or accept it with a reason.")
  end
end
