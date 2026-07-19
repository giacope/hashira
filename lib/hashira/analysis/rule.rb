# frozen_string_literal: true

module Hashira
  module Analysis
    class Rule
      def initialize(project, graph)
        @project = project
        @graph = graph
      end

      private

      attr_reader :project, :graph

      def metrics = @metrics ||= graph.metrics

      def finding(**attributes)
        Finding.new(kind: self.class::KIND, cycle: nil, **attributes)
      end
    end
  end
end
