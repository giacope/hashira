# frozen_string_literal: true

class Hashira::CLI
  MISUSE = 2
  BROKEN = 70

  def self.run(argv)
    dispatch(Options.parse(argv))
  rescue Hashira::Error => error
    failure(error)
  rescue StandardError => error
    crash(error)
  end

  def self.dispatch(options) = usage?(options) ? Usage.public_send(options.mode) : new(options).run

  def self.usage?(options) = Usage::PAGES.include?(options.mode)

  def self.failure(error)
    Kernel.warn("hashira: #{error.message}")
    MISUSE
  end

  def self.crash(error)
    Hashira::Report::Notices.new.crashed(error)
    BROKEN
  end

  def initialize(options)
    @started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    @options = options
    @notices = Hashira::Report::Notices.new
    @pipeline = options.pipeline
  end

  def run
    Run.new(@pipeline, @options).status.tap { @notices.finished(@pipeline.project.files.size, elapsed) }
  end

  private

  def elapsed = format("%.1f", Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started)
end
