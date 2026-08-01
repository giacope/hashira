# frozen_string_literal: true

class Hashira::Analysis::SdpCheck
  def initialize(dependencies, metrics)
    @dependencies = dependencies
    @metrics = metrics
  end

  def violations
    @dependencies.flat_map do |from, tos|
      tos.select { @metrics[it].instability > @metrics[from].instability }.map { [from, it] }
    end
  end
end
