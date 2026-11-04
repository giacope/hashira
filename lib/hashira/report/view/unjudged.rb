# frozen_string_literal: true

class Hashira::Report::View::Unjudged
  def initialize(kinds:, history:, judged:)
    @kinds = kinds
    @history = history
    @judged = judged
  end

  def verdict
    return "none ✓ — structure is healthy" if @kinds.empty?
    return "none — #{named} could not judge: #{reason}" unless @judged
    "none ✓ for the kinds judged; #{named} not judged (#{reason})"
  end

  def to_a = @kinds.map { { kind: it, reason: } }

  private

  def reason = @history.to_s

  def named = @kinds.join(", ")
end
