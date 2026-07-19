# frozen_string_literal: true

module Hashira
  module CI
    class Gate
      def initialize(findings, kinds, io: $stdout)
        @findings = findings
        @kinds = kinds
        @io = io
      end

      def check
        offending = @findings.all.select { @kinds.include?(_1.kind) }
        return report_clean if offending.empty?

        offending.each { Report::FindingLines.new(_1, io: @io).print }
        @io.puts "\nGate FAILED: #{offending.size} finding(s) of kind #{@kinds.join(", ")}."
        1
      end

      private

      def report_clean
        @io.puts "Gate OK: no findings of kind #{@kinds.join(", ")}."
        0
      end
    end
  end
end
