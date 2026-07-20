# frozen_string_literal: true

module Hashira
  module Analysis
    class SdpCheck
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
  end
end
