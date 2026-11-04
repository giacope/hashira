# frozen_string_literal: true

class Hashira::CLI::Failure
  def initialize(error)
    @error = error
  end

  def print = Kernel.warn("hashira: #{@error.message}")

  def status = 2
end
