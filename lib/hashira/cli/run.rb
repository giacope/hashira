# frozen_string_literal: true

module Hashira
  class CLI
    class Run
      MODES = { update_baseline: :update_baseline, ratchet: :check_ratchet,
                fail_on: :check_gate, json: :print_json,
                dot: :print_diagram, mermaid: :print_diagram }.freeze

      def initialize(pipeline, options)
        @pipeline = pipeline
        @options = options
      end

      def exit_code = send(MODES.fetch(@options.mode, :print_text))

      private

      def graph = @pipeline.graph

      def ratchet = CI::Ratchet.new(graph, @options.baseline)

      def update_baseline = ratchet.update

      def check_ratchet = ratchet.check

      def findings = @findings ||= CI::Accepted.load(@options.baseline).screen(@pipeline.findings)

      def check_gate = CI::Gate.new(findings, @options.fail_on).check

      def print_json = Report::Json.new(graph, findings).print

      def print_diagram = Diagram::Renderer.new(graph, @options.mode).display

      def print_text = Report::Text.new(@pipeline.project, graph, findings).print
    end
  end
end
