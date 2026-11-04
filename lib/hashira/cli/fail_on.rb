# frozen_string_literal: true

require_relative "../checks"

class Hashira::CLI::FailOn
  EVERY = "all"

  private_constant :EVERY

  def initialize(kinds = [], checks = Hashira::Checks.new)
    @kinds = kinds
    @checks = checks
  end

  def every? = @kinds.include?(EVERY)

  def named = @kinds - [EVERY]

  def names = @checks.names.merge(EVERY => EVERY)

  def to_a = every? ? [EVERY] : @kinds
end
