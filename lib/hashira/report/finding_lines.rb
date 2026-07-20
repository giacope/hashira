# frozen_string_literal: true

module Hashira
  module Report
    class FindingLines
      SAMPLE = 4

      def initialize(finding, indent: "", io: $stdout)
        @finding = finding
        @indent = indent
        @io = io
      end

      def print
        @io.puts "#{@indent}#{@finding.kind}: #{@finding.message}"
        @finding.evidence.first(SAMPLE).each { @io.puts "#{@indent}    · #{it}" }
      end

      def print_with_overflow
        print
        overflow = @finding.evidence.size - SAMPLE
        @io.puts "#{@indent}    · … (#{overflow} more)" if overflow.positive?
      end
    end
  end
end
