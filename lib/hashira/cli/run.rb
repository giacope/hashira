# frozen_string_literal: true

class Hashira::CLI::Run
  MODES = { update: :update, ratchet: :check, fail_on: :guard, json: :json, dot: :diagram, mermaid: :diagram }.freeze

  def initialize(pipeline, options)
    @pipeline = pipeline
    @options = options
  end

  def status = __send__(MODES.fetch(@options.mode, :text))

  private

  def graph = @pipeline.graph

  def findings = @findings ||= accepted.screen(@pipeline.findings)

  def accepted
    path = @options.baseline
    stop = Hashira::CI::Baseline.trouble(path)
    raise(Hashira::Error, stop) if stop
    Hashira::CI::Accepted.load(path)
  end

  def update
    ratchet.update
  rescue SystemCallError => error
    raise(Hashira::Error, "cannot write #{@options.baseline} (#{error.message})")
  end

  def check
    stop = ratchet.blocker
    raise(Hashira::Error, stop) if stop
    ratchet.check
  end

  def guard = gate.check

  def diagram = source.print

  def json = report(Hashira::Report::Json)

  def text = report(Hashira::Report::Text)

  def report(kind)
    Hashira::Report::Notices.new(@pipeline).print
    kind.new(view).print
  end

  def ratchet = @ratchet ||= Hashira::CI::Ratchet.new(graph, findings.all, @options.baseline)

  def gate = Hashira::CI::Gate.new(findings, @options.fail_on)

  def source = Hashira::Diagram::Source.new(graph, @options.mode)

  def view
    Hashira::Report::View.new(
      project: @pipeline.project, graph: (graph if @pipeline.enabled?(:coupling)),
      complexity: @pipeline.complexity, duplication: @pipeline.duplication,
      hotspots: @pipeline.hotspots, findings:
    )
  end
end
