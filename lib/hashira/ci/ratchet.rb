# frozen_string_literal: true

class Hashira::CI::Ratchet
  NEWER = "Not ratcheted: %s — kinds this baseline predates. Record them with --update-baseline."

  def initialize(graph, findings, baseline, io: $stdout)
    @graph = graph
    @findings = findings
    @baseline = baseline
    @io = io
  end

  def record
    @baseline.write(edges, scored(@findings), packaging:)
    @io.puts("Baseline updated: #{edges.size} edges, #{recorded}.")
  end

  def check(focus)
    history = @baseline.history
    newer(history)
    compared = focus.narrowing? ? Hashira::CI::Slice.new : Hashira::CI::Sweep.new
    deltas = history.findings(compared, scored(history.judged(@findings)))
    edges = compared.edges(history.drift(@graph.edges))
    report = Hashira::CI::RatchetReport.new(@graph, @findings, io: @io)
    report.print(edges, deltas, tally(compared))
    report.status(edges, deltas)
  end

  def update = Hashira::CI::Update.new(self, @baseline)

  def vet = @baseline.vet(packaging)

  private

  def packaging = @graph.packaging.to_s

  def recorded = collapsed(@findings.size, scored(@findings).size)

  def newer(history)
    left = history.unjudged(@findings)
    @io.puts(NEWER % left.join(", ")) unless left.empty?
  end

  def collapsed(total, keys) = keys == total ? "#{total} findings" : "#{total} findings (#{keys} distinct)"

  def edges = @graph.edges.map(&:to_s)

  def tally(compared) = compared.counts("#{@graph.edges.size} edges", "#{@findings.size} findings").join(", ")

  def scored(findings) = findings.reduce(Hashira::CI::Marks.new) { |marks, finding| finding.scored(marks) }
end
