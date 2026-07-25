# frozen_string_literal: true

module Hashira
  module CI
    class FindingDiffReport
      def initialize(findings, io: $stdout)
        @findings = findings
        @io = io
      end

      def print(diff)
        introduced(diff.added).each { print_finding(it) }
        Improvement.new("Findings resolved", io: @io).print(diff.removed)
      end

      private

      def introduced(added) = added.filter_map { |signature| @findings.find { it.signature == signature } }

      def print_finding(finding)
        @io.puts "NEW FINDING:"
        Report::FindingLines.new(finding, indent: "  ", io: @io).print_with_overflow
      end
    end
  end
end
