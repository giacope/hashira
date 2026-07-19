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
          tos.select { @metrics[_1].instability > @metrics[from].instability }.map { [from, _1] }
        end
      end
    end
  end
end
