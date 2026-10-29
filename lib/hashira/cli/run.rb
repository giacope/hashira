# frozen_string_literal: true

class Hashira::CLI::Run
  def initialize(pipeline, output, judgement, record)
    @pipeline = pipeline
    @output = output
    @judgement = judgement
    @record = record
  end

  def status = __send__(@output.action)

  private

  def graph = @pipeline.graph

  def findings = @_findings ||= @record.accepted.screen(sieve.narrow(screened.to_a.fetch(0)))

  def screened = @pipeline.screened

  def sieve = @judgement.sieve(@pipeline.focus)

  def update = shown(ratchet.update)

  def check
    judged = ratchet
    judged.vet
    judged.check(sieve)
  end

  def guard = shown(Hashira::CI::Gate.new(findings, @judgement.gated(checked)))

  def diagram = shown(@output.drawing(graph))

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

  def ratchet = Hashira::CI::Ratchet.new(graph, findings.to_a, @record.baseline(@pipeline))

  def checked = asked { @pipeline.checks?(it) }

  def unjudged
    left = asked { @pipeline.unjudged?(it) }
    Hashira::Report::View::Unjudged.new(kinds: left, history: @pipeline.depth, judged: checked.any?)
  end

  def asked(checks = Hashira::Checks.new)
    kept = sieve
    checks.select { yield(it) && @pipeline.enabled?(checks.owner(it)) && kept.keeps?(it) }
  end

  def view
    analyses = Hashira::Report::View::Analyses.new(
      (graph if @pipeline.enabled?(:coupling)), @pipeline.complexity, @pipeline.duplication, @pipeline.hotspots
    )
    verdicts = Hashira::Report::View::Verdicts.new(findings, screened, unjudged)
    Hashira::Report::View.new(@pipeline.project, analyses, verdicts, @output.layout)
  end
end
