# frozen_string_literal: true

class Hashira::CLI::Run
  def initialize(output, sieve, record)
    @output = output
    @sieve = sieve
    @record = record
  end

  def call(outcome, coverage) = __send__(@output.action, outcome, coverage)

  private

  def findings(outcome) = @record.accepted.screen(@sieve.narrow(outcome.screened.to_a.fetch(0)))

  def update(outcome, coverage) = shown(ratchet(outcome, coverage).update)

  def check(outcome, coverage)
    judged = ratchet(outcome, coverage)
    judged.vet
    judged.check(@sieve)
  end

  def guard(outcome, coverage) = shown(Hashira::CI::Gate.new(findings(outcome), @sieve.gated(coverage.checked(@sieve))))

  def diagram(outcome, _coverage) = shown(@output.drawing(outcome.graph))

  def json(outcome, coverage) = listed(outcome, coverage, &:json)

  def text(outcome, coverage) = listed(outcome, coverage, &:text)

  def listed(outcome, coverage)
    outcome.notify(Hashira::Report::Warnings.new)
    shown(yield(view(outcome, coverage)))
  end

  def shown(printer)
    printer.print
    printer.status
  end

  def ratchet(outcome, coverage)
    Hashira::CI::Ratchet.new(outcome.graph, findings(outcome).to_a, @record.baseline(coverage))
  end

  def view(outcome, coverage)
    verdicts = Hashira::Report::View::Verdicts.new(findings(outcome), outcome.screened, coverage.unjudged(@sieve))
    outcome.view(verdicts, @output.layout)
  end
end
