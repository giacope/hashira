# frozen_string_literal: true

module Evaluation
  Z = 1.96

  Tally =
    Data.define(:population, :sampled, :labeled, :positive) do
      def to_h = { "population" => population, "sampled" => sampled, "labeled" => labeled }.merge(judged)

      def judged = labeled.zero? ? { "tp" => 0, "precision" => nil } : { "tp" => positive }.merge(bounds)

      def share = positive.fdiv(labeled)

      def bounds
        { "precision" => share.round(3), "low" => (middle - spread).round(3), "high" => (middle + spread).round(3) }
      end

      def shrink = 1 + ((Z**2) / labeled)

      def middle = (share + ((Z**2) / (2 * labeled))) / shrink

      def spread = Z * Math.sqrt((share * (1 - share) / labeled) + ((Z**2) / (4 * (labeled**2)))) / shrink
    end
end
