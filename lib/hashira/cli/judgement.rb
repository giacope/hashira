# frozen_string_literal: true

class Hashira::CLI::Judgement
  def initialize(kinds, fail_on, strict, draft)
    @kinds = kinds
    @fail_on = fail_on
    @strict = strict
    @draft = draft
  end

  def pipeline(scope, record, notices, checks = Hashira::Checks.new)
    @draft.chosen(named: @kinds + @fail_on, kinds: @kinds, every: checks, strict: @strict).call(scope, record, notices)
  end

  def sieve(scope) = Hashira::CLI::Sieve.new(scope, @kinds, @fail_on)

  def to_h = { kinds: @kinds, fail_on: @fail_on, strict: @strict, **@draft.chosen(strict: @strict).to_h }
end
