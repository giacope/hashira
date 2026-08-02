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

  def findings = @findings ||= Hashira::CI::Accepted.load(@options.baseline).screen(@pipeline.findings)

  def update = ratchet.update

  def check
    stop = ratchet.blocker
    raise(Hashira::Error, stop) if stop
    ratchet.check
  end

  def guard = gate.check

  def diagram = renderer.display

  def json = report(Hashira::Report::Json)

  def text = report(Hashira::Report::Text)

  def report(kind) = kind.new(view).print

  def ratchet = @ratchet ||= Hashira::CI::Ratchet.new(graph, findings.all, @options.baseline)

  def gate = Hashira::CI::Gate.new(findings, @options.fail_on)

  def renderer = Hashira::Diagram::Renderer.new(graph, @options.mode)

  def view
    Hashira::Report::View.new(
      project: @pipeline.project, graph: (graph if @pipeline.enabled?(:coupling)),
      complexity: @pipeline.complexity, duplication: @pipeline.duplication,
      hotspots: @pipeline.hotspots, findings:
    )
  end
end
