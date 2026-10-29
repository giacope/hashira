# frozen_string_literal: true

class Hashira::CI::Scope
  def initialize(analyzers:, targets:)
    @analyzers = analyzers
    @targets = targets
  end

  def to_h = { analyzers: @analyzers.map(&:to_s).sort, targets: @targets.sort }
end
