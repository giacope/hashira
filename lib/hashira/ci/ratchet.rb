# frozen_string_literal: true

class Hashira::CI::Ratchet
  NEWER = "Not ratcheted: %s — kinds this baseline predates. Record them with --update-baseline."

  def initialize(graph, findings, baseline, io: $stdout)
    @graph = graph
    @findings = findings
    @baseline = baseline
    @io = io
  end

  def update
    @baseline.write(edges, scored(@findings), packaging:)
    @io.puts("Baseline updated: #{edges.size} edges, #{recorded}.")
    Hashira::CI::Status::CLEAN
  end

  def check(focus)
    newer
    compared = focus.narrowing? ? Hashira::CI::Slice.new(@baseline) : Hashira::CI::Sweep.new(@baseline)
    Hashira::CI::RatchetReport.new(@graph, @findings, io: @io)
      .print(compared.edges(drift), delta(compared), tally(compared))
  end

  def blocker
    return "no baseline at #{@baseline.path} — run --update-baseline first" unless @baseline.exist?
    drifted.first
  end

  private

  def drifted = [(mismatch unless @baseline.packaging == packaging), *narrowed(@baseline.wanted)].compact

  def narrowed(wanted)
    [
      widened("the analyzers", @baseline.analyzers, wanted[:analyzers]),
      widened("the directories", @baseline.targets, wanted[:targets])
    ]
  end

  def widened(flag, was, now)
    return if was.sort == now.sort
    phrase(flag, was, now)
  end

  def phrase(flag, was, now)
    "baseline #{@baseline.path} was recorded with #{flag} #{was.join(", ")}, but this run " \
      "uses #{now.join(", ")} — rerun the recorded way, or refresh it with --update-baseline"
  end

  def packaging = @graph.packaging.to_s

  def recorded = collapsed(@findings.size, scored(@findings).size)

  def judged = @_judged ||= @findings.reject { @baseline.predates?(it.kind) }

  def newer
    unseen = (@findings - judged).map(&:kind).tally
    @io.puts(NEWER % unseen.map { |kind, count| "#{count} #{kind}" }.join(", ")) unless unseen.empty?
  end

  def collapsed(total, keys) = keys == total ? "#{total} findings" : "#{total} findings (#{keys} distinct)"

  def mismatch
    recorded = @baseline.packaging
    "baseline #{@baseline.path} was recorded with --package-by #{recorded}, but this run " \
      "uses #{packaging} — rerun with --package-by #{recorded}, or refresh it with --update-baseline"
  end

  def edges = @graph.edges.map(&:to_s)

  def tally(compared) = compared.counts("#{@graph.edges.size} edges", "#{@findings.size} findings").join(", ")

  def scored(findings) = findings.group_by(&:signature).sort.to_h { |key, group| [key, mark(group)] }

  def mark(group) = Hashira::CI::Mark.new(magnitude: group.filter_map(&:magnitude).max, trace: group.first.trace)

  def drift = Hashira::CI::Diff.new(added: fresh, removed: @baseline.edges - edges)

  def fresh = @graph.edges.reject { @baseline.edges.include?(it.to_s) }

  def delta(compared)
    compared.findings(scored(judged)) if @baseline.findings?
  end
end
