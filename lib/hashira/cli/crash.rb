# frozen_string_literal: true

class Hashira::CLI::Crash
  def initialize(error, notices)
    @error = error
    @notices = notices
  end

  def print = @notices.crashed(@error)

  def status = 70
end
