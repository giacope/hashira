# frozen_string_literal: true

class Hashira::CLI::Options
  def self.parse(argv) = Hashira::CLI::Settings.new(argv).options

  def initialize(output, scope, judgement, record)
    @output = output
    @scope = scope
    @judgement = judgement
    @record = record
  end

  def status(_usage, notices, clock = Process)
    started = clock.clock_gettime(Process::CLOCK_MONOTONIC)
    pipeline = @judgement.pipeline(@scope, @record, notices)
    pipeline.call(Hashira::CLI::Run.new(@output, @judgement.sieve(@scope), @record)).tap do
      pipeline.finished(notices, format("%.1f", clock.clock_gettime(Process::CLOCK_MONOTONIC) - started))
    end
  end

  def to_h = [@output, @scope, @judgement, @record].map(&:to_h).reduce(:merge)
end
