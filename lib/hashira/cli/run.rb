# frozen_string_literal: true

class Hashira::CLI::Run
  def initialize(pipeline, options, checks = Hashira::Checks.new)
    @pipeline = pipeline
    @options = options
    @checks = checks
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

  def update = shown(ratchet.update(@options.baseline))

  def check
    ratchet.vet
    ratchet.check(sieve)
  end

  def guard = shown(Hashira::CI::Gate.new(findings, gated))

  def diagram = shown(source)

  def json = report(Hashira::Report::Json)

  def text = report(Hashira::Report::Text)

  def report(kind)
    notices
    shown(kind.new(view))
  end

  def shown(printer)
    printer.print
    printer.status
  end

  def notices = @pipeline.notify(Hashira::Report::Notices.new)

  def ratchet = @_ratchet ||= Hashira::CI::Ratchet.new(graph, findings.all, baseline)

  def baseline
    Hashira::CI::Baseline.new(@options.baseline, analyzers: @options.analyzers, targets:, kinds: @checks.to_a)
  end

  def targets = @pipeline.targets(@options.home)

  def gated = Hashira::CLI::FailOn.new(@options.fail_on).every? ? checked : @options.fail_on

  def checked = asked { @pipeline.checks?(it) }

  def unjudged
    left = asked { @pipeline.unjudged?(it) }
    Hashira::Report::Unjudged.new(kinds: left, depth: @pipeline.depth, judged: checked.any?)
  end

  def asked(&) = @checks.select { yield(it) && owned?(it) && sieve.keeps?(it) }

  def owned?(kind) = @pipeline.enabled?(@checks.owner(kind))

  def source = Hashira::Diagram::Source.new(graph, @options.mode)

  def view
    Hashira::Report::View.new(
      project: @pipeline.project, graph: (graph if @pipeline.enabled?(:coupling)),
      complexity: @pipeline.complexity, duplication: @pipeline.duplication,
      hotspots: @pipeline.hotspots, findings:, top: @options.top, compact: @options.compact, screened:, unjudged:
    )
  end
end
