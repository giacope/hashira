# frozen_string_literal: true

class Hashira::CLI::Run
  def initialize(pipeline, options)
    @pipeline = pipeline
    @options = options
  end

  MODES = { update: :update, ratchet: :check, fail_on: :guard }
    .merge(json: :json, dot: :diagram, mermaid: :diagram).freeze

  def status = __send__(MODES.fetch(@options.mode, :text))

  private

  def graph = @pipeline.graph

  def findings = @_findings ||= accepted.screen(sieve.narrow(screened.kept))

  def screened = @pipeline.screened

  def sieve = @_sieve ||= Hashira::CLI::Sieve.new(@pipeline.focus, @options.kinds)

  def accepted = Hashira::CI::Accepted.build(@options.baseline)

  def update
    ratchet.update
  rescue SystemCallError => error
    raise(Hashira::Error, "cannot write #{@options.baseline} (#{error.message})")
  end

  def check
    stop = ratchet.blocker
    raise(Hashira::Error, stop) if stop
    ratchet.check(sieve)
  end

  def guard = gate.check

  def diagram = source.print

  def json = report(Hashira::Report::Json)

  def text = report(Hashira::Report::Text)

  def report(kind)
    notices
    kind.new(view).print
  end

  def notices = @pipeline.notify(Hashira::Report::Notices.new)

  def ratchet = @_ratchet ||= Hashira::CI::Ratchet.new(graph, findings.all, baseline)

  def baseline
    Hashira::CI::Baseline.new(@options.baseline, analyzers: @options.analyzers, targets:, kinds: Hashira::Pipeline::KINDS)
  end

  def targets = @pipeline.targets(@options.home)

  def gate = Hashira::CI::Gate.new(findings, gated)

  def gated = @options.fail_on.include?(Hashira::CLI::FailOn::EVERY) ? checked : @options.fail_on

  def checked = Hashira::Pipeline::KINDS.select { checks?(it) && sieve.keeps?(it) }

  def checks?(kind)
    @pipeline.checks?(kind) && @pipeline.enabled?(Hashira::CLI::FailOn::OWNERS.fetch(kind))
  end

  def source = Hashira::Diagram::Source.new(graph, @options.mode)

  def view
    Hashira::Report::View.new(
      project: @pipeline.project, graph: (graph if @pipeline.enabled?(:coupling)),
      complexity: @pipeline.complexity, duplication: @pipeline.duplication,
      hotspots: @pipeline.hotspots, findings:, top: @options.top, compact: @options.compact, screened:
    )
  end
end
