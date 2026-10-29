# frozen_string_literal: true

class Hashira::CLI::Sieve
  def initialize(focus, kinds)
    @focus = focus
    @kinds = kinds
  end

  def narrowing? = @focus.narrowing? || @kinds.any?

  def narrow(findings) = @kinds.empty? ? findings : findings.select { it.of?(@kinds) }

  def keeps?(kind) = @kinds.empty? || @kinds.include?(kind)
end
