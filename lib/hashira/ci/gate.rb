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
        offending = @findings.all.select { @kinds.include?(it.kind) }
        offending.empty? ? report_clean : report_failure(offending)
      end

      private

      def report_failure(offending)
        offending.each { Report::FindingLines.new(it, io: @io).print }
        @io.puts "\nGate FAILED: #{offending.size} finding(s) of kind #{@kinds.join(", ")}."
        1
      end

      def report_clean
        @io.puts "Gate OK: no findings of kind #{@kinds.join(", ")}."
        0
      end
    end
  end
end
