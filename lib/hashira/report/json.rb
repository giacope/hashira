# frozen_string_literal: true

require "json"

module Hashira
  module Report
    class Json
      def initialize(view, io: $stdout)
        @view = view
        @io = io
      end

      def print
        @io.puts JSON.pretty_generate(payload)
        0
      end

      private

      def payload = base.merge(graph_payload).merge(sections.compact)

      def base = { findings: @view.findings.all.map(&:to_h), accepted: accepted_entries }

      def graph_payload
        graph = @view.graph
        graph ? GraphPayload.new(graph).to_h : {}
      end

      def sections
        { complexity: (complexity_payload if @view.complexity),
          duplication: (duplication_payload if @view.duplication),
          hotspots: @view.hotspots&.files&.map(&:to_h) }
      end

      def accepted_entries
        @view.findings.accepted.map { |finding, reason| finding.to_h.merge(reason:) }
      end

      def complexity_payload = { methods: method_scores, classes: class_scores }

      def method_scores = @view.complexity.methods.map(&:to_h)

      def class_scores = @view.complexity.classes.map(&:to_h)

      def duplication_payload = @view.duplication.clusters.map { Duplication::Delta.new(it).to_h }
    end
  end
end
