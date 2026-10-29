# frozen_string_literal: true

class Hashira::CLI::Run
  def initialize(
    pipeline, options, checks = Hashira::Checks.new, sieve = Hashira::CLI::Sieve.new(pipeline.focus, options.kinds)
  )
    @pipeline = pipeline
    @options = options
    @checks = checks
    @sieve = sieve
  end

  MODES = { update: :update, ratchet: :check, fail_on: :guard }
    .merge(json: :json, dot: :diagram, mermaid: :diagram).freeze

  def status = __send__(MODES.fetch(@options.mode, :text))

  private

  def graph = @pipeline.graph

  def findings = @_findings ||= accepted.screen(@sieve.narrow(screened.to_a.fetch(0)))

  def screened = @pipeline.screened

  def accepted = Hashira::CI::Accepted.build(@options.baseline)

  def update = shown(ratchet.update(@options.baseline))

  def check
    judged = ratchet
    judged.vet
    judged.check(@sieve)
  end

  def guard = shown(Hashira::CI::Gate.new(findings, gated))

  def diagram = shown(source)

  def json
    notices
    shown(view.json)
  end

  def text
    notices
    shown(view.text)
  end

  def shown(printer)
    printer.print
    printer.status
  end

  def notices = @pipeline.notify(Hashira::Report::Warnings.new)

  def ratchet = Hashira::CI::Ratchet.new(graph, findings.to_a, baseline)

  def baseline
    Hashira::CI::Baseline.new(@options.baseline, analyzers: @options.analyzers, targets:, kinds: @checks.to_a)
  end

  def targets = @pipeline.targets(@options.home)

  def gated = Hashira::CLI::FailOn.new(@options.fail_on).every? ? checked : @options.fail_on

  def checked = asked { @pipeline.checks?(it) }

  def unjudged
    left = asked { @pipeline.unjudged?(it) }
    Hashira::Report::View::Unjudged.new(kinds: left, history: @pipeline.depth, judged: checked.any?)
  end

  def asked(&) = @checks.select { yield(it) && owned?(it) && @sieve.keeps?(it) }

  def owned?(kind) = @pipeline.enabled?(@checks.owner(kind))

  def source = Hashira::Diagram::Source.new(graph, @options.mode)

  def view
    analyses = Hashira::Report::View::Analyses.new(
      (graph if @pipeline.enabled?(:coupling)), @pipeline.complexity, @pipeline.duplication, @pipeline.hotspots
    )
    verdicts = Hashira::Report::View::Verdicts.new(findings, screened, unjudged)
    layout = Hashira::Report::View::Layout.new(@options.top, @options.compact)
    Hashira::Report::View.new(@pipeline.project, analyses, verdicts, layout)
  end
end
