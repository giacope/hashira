# frozen_string_literal: true

class Hashira::CLI::Session
  def initialize(argv, usage = Hashira::CLI::Usage.new, notices = Hashira::Report::Notices.new)
    @argv = argv
    @usage = usage
    @notices = notices
  end

  def status
    Hashira::CLI::Options.parse(@argv).status(@usage, @notices)
  rescue Hashira::Error => error
    shown(Hashira::CLI::Failure.new(error))
  rescue StandardError => error
    shown(Hashira::CLI::Crash.new(error, @notices))
  end

  private

  def shown(outcome)
    outcome.print
    outcome.status
  end
end
