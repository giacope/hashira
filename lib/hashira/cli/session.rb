# frozen_string_literal: true

class Hashira::CLI::Session
  MISUSE = 2
  BROKEN = 70

  def initialize(argv)
    @argv = argv
  end

  def status
    dispatch(Hashira::CLI::Options.parse(@argv))
  rescue Hashira::Error => error
    failure(error)
  rescue StandardError => error
    crash(error)
  end

  private

  def dispatch(options)
    usage?(options) ? Hashira::CLI::Usage.new.public_send(options.mode) : timed(options)
  end

  def usage?(options) = Hashira::CLI::Usage::PAGES.include?(options.mode)

  def timed(options, clock: Process)
    started = clock.clock_gettime(Process::CLOCK_MONOTONIC)
    pipeline = options.pipeline
    Hashira::CLI::Run.new(pipeline, options).status.tap do
      Hashira::Report::Notices.new.finished(pipeline.project.files.size, elapsed(started, clock))
    end
  end

  def elapsed(started, clock) = format("%.1f", clock.clock_gettime(Process::CLOCK_MONOTONIC) - started)

  def failure(error)
    Kernel.warn("hashira: #{error.message}")
    MISUSE
  end

  def crash(error)
    Hashira::Report::Notices.new.crashed(error)
    BROKEN
  end
end
