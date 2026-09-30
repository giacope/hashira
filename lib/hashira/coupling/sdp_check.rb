# frozen_string_literal: true

class Hashira::Coupling::SdpCheck
  def initialize(dependencies, metrics)
    @dependencies = dependencies
    @metrics = metrics
  end

  def violations
    @dependencies.flat_map do |from, tos|
      tos.select { @metrics[it].level > @metrics[from].level }.map { [from, it] }
    end
  end
end
