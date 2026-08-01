# frozen_string_literal: true

class Hashira::CI::Ratchet
  def initialize(graph, findings, baseline_path, io: $stdout)
    @graph = graph
    @findings = findings
    @baseline = Hashira::CI::Baseline.load(baseline_path)
    @io = io
  end

  def update
    @baseline.write(edges, digests, packaging:)
    @io.puts("Baseline updated: #{edges.size} edges, #{digests.size} findings.")
    0
  end

  def check
    raise(Hashira::Error, "no baseline at #{@baseline.path} — run --update-baseline first") unless @baseline.exist?
    vet
    Hashira::CI::RatchetReport.new(@graph, @findings, io: @io).print(drift, delta)
  end

  private

  def packaging = @graph.packaging.to_s

  def vet
    return if @baseline.packaging == packaging
    raise(Hashira::Error, mismatch)
  end

  def mismatch
    recorded = @baseline.packaging
    "baseline #{@baseline.path} was recorded with --package-by #{recorded}, but this run " \
      "uses #{packaging} — rerun with --package-by #{recorded}, or refresh it with --update-baseline"
  end

  def edges = @graph.edges.map(&:to_s)

  def digests = @findings.map(&:signature).uniq.sort

  def drift = Hashira::CI::Diff.new(added: fresh, removed: @baseline.edges - edges)

  def fresh = @graph.edges.reject { @baseline.edges.include?(it.to_s) }

  def delta
    Hashira::CI::Diff.between(digests, @baseline.findings) if @baseline.findings?
  end
end
