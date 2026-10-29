# frozen_string_literal: true

class Hashira::CLI::Judgement
  def initialize(kinds, fail_on, strict, rules)
    @kinds = kinds
    @fail_on = fail_on
    @strict = strict
    @rules = rules
  end

  def project(directories, record, checks = Hashira::Checks.new)
    record.project(directories, ruled.naming(@kinds + @fail_on).narrowed(@kinds, checks))
  end

  def sieve(focus) = Hashira::CLI::Sieve.new(focus, @kinds)

  def gated(checked) = Hashira::CLI::FailOn.new(@fail_on).every? ? checked : @fail_on

  def to_h = { kinds: @kinds, fail_on: @fail_on, strict: @strict, rules: ruled }

  private

  def ruled = @strict ? @rules.tightened : @rules
end
