# frozen_string_literal: true

class Hashira::CLI::Session
  def initialize(argv, usage = Hashira::CLI::Usage.new, notices = Hashira::Report::Notices.new)
    @argv = argv
    @usage = usage
    @notices = notices
  end

  def status
    dispatch(Hashira::CLI::Options.parse(@argv))
  rescue Hashira::Error => error
    shown(Hashira::CLI::Failure.new(error))
  rescue StandardError => error
    shown(Hashira::CLI::Crash.new(error, @notices))
  end

  private

  def dispatch(options)
    @usage.page?(options.mode) ? page(options.mode) : timed(options)
  end

  def page(mode)
    @usage.public_send(mode)
    @usage.status
  end

  def timed(options, clock: Process)
    started = clock.clock_gettime(Process::CLOCK_MONOTONIC)
    pipeline = options.pipeline
    Hashira::CLI::Run.new(pipeline, options).status.tap do
      @notices.finished(pipeline.size, elapsed(started, clock))
    end
  end

  def elapsed(started, clock) = format("%.1f", clock.clock_gettime(Process::CLOCK_MONOTONIC) - started)

  def shown(outcome)
    outcome.print
    outcome.status
  end
end
