# frozen_string_literal: true

class Hashira::CLI::Sieve
  def initialize(scope, kinds, fail_on)
    @scope = scope
    @kinds = kinds
    @fail_on = fail_on
  end

  def narrowing? = @scope.narrowing? || @kinds.any?

  def narrow(findings) = @kinds.empty? ? findings : findings.select { it.of?(@kinds) }

  def keeps?(kind) = @kinds.empty? || @kinds.include?(kind)

  def gated(checked) = Hashira::CLI::FailOn.new(@fail_on).every? ? checked : @fail_on
end
