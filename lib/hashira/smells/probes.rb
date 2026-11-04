# frozen_string_literal: true

class Hashira::Smells::Probes
  def initialize(subject, foreign, words)
    @subject = subject
    @foreign = foreign
    @words = words
  end

  def of(calls) = calls.map { Hashira::Smells::Probe.new(it, @subject, @foreign, @words) }
end
