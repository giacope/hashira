# frozen_string_literal: true

class Hashira::CLI
  def self.run(argv)
    options = Options.parse(argv)
    usage?(options) ? Usage.public_send(options.mode) : new(options).run
  rescue Hashira::Error => error
    failure(error)
  end

  def self.usage?(options) = Usage::PAGES.include?(options.mode)

  def self.failure(error)
    warn("hashira: #{error.message}")
    1
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
