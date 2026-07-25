# frozen_string_literal: true

module Hashira
  module Complexity
    class Rollup
      def initialize(scores)
        @scores = scores
      end

      def classes = @scores.group_by { class_name(it.subject) }.map { |name, group| score(name, group) }

      private

      def score(name, group)
        ClassScore.new(name:, cognitive: group.sum(&:cognitive), method_count: group.size,
                       peak: group.map(&:cognitive).max)
      end

      def class_name(subject) = subject.split(/[#.]/, 2).first
    end
  end
end
