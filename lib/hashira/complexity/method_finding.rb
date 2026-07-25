# frozen_string_literal: true

module Hashira
  module Complexity
    class MethodFinding
      ADVICE = {
        "if" => "flatten the branching — guard clauses, early returns, or polymorphism.",
        "elsif" => "replace the elsif ladder with a lookup or polymorphic dispatch.",
        "else" => "flatten the branching — guard clauses, early returns, or polymorphism.",
        "case" => "a case this size often wants polymorphism or a dispatch table.",
        "boolean" => "name the compound condition in a predicate method.",
        "rescue" => "narrow the rescue, or lift error handling to the caller.",
        "while" => "extract the loop body into its own method.",
        "until" => "extract the loop body into its own method.",
        "for" => "extract the loop body into its own method.",
        "unless" => "invert to a guard clause or a named predicate.",
        "ternary" => "extract the nested ternary into a named method."
      }.freeze

      def initialize(score)
        @score = score
      end

      def to_finding
        Analysis::Finding.new(kind: "complexity", package: @score.subject, cycle: nil,
                              message:, evidence:)
      end

      private

      def message
        "#{@score.subject} — cognitive #{@score.cognitive}, #{@score.calls} calls " \
          "(#{@score.file}:#{@score.line}). #{advice}"
      end

      def evidence
        @score.increments.group_by(&:label).map { |label, incs| line_summary(label, incs) }
      end

      def line_summary(label, incs)
        lines = incs.map(&:line).uniq
        "#{label} +#{incs.sum(&:cost)} (line#{"s" if lines.size > 1} #{lines.join(", ")})"
      end

      def advice = ADVICE.fetch(dominant)

      def dominant
        @score.increments.group_by(&:label).transform_values { it.sum(&:cost) }.max_by(&:last).first
      end
    end
  end
end
