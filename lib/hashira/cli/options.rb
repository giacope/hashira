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
    pipeline = @scope.pipeline(@judgement, @record, notices)
    Hashira::CLI::Run.new(pipeline, @output, @judgement, @record).status.tap do
      notices.finished(pipeline.size, format("%.1f", clock.clock_gettime(Process::CLOCK_MONOTONIC) - started))
    end
  end

  def to_h = [@output, @scope, @judgement, @record].map(&:to_h).reduce(:merge)
end
