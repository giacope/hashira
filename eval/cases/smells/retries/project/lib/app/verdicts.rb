module App
  class Verdicts
    def initialize(runner)
      @runner = runner
    end

    def settle(job)
      outcome = @runner.verdict(job, first: true)
      outcome.lost? ? @runner.verdict(job, first: true) : outcome
    end

    def describe(job)
      return "none" unless @runner.verdict(job, first: true)
      @runner.verdict(job, first: true).to_s
    end
  end
end
