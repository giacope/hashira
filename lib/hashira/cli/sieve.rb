# frozen_string_literal: true

class Hashira::CLI::Sieve
  def initialize(focus, kinds)
    @focus = focus
    @kinds = kinds
  end

  def narrowing? = @focus.narrowing? || @kinds.any?

  def narrow(findings) = findings.select { keeps?(it.kind) }

  def keeps?(kind) = @kinds.empty? || @kinds.include?(kind)
end
