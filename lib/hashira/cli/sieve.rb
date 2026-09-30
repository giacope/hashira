# frozen_string_literal: true

class Hashira::CLI::Sieve
  def initialize(focus, kinds)
    @focus = focus
    @kinds = kinds
  end

  def narrowing? = @focus.narrowing? || @kinds.any?

  def narrow(findings) = @kinds.empty? ? findings : findings.select { @kinds.include?(it.kind) }
end
