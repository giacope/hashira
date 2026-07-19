# frozen_string_literal: true

module Hashira
  module Analysis
    class SdpViolationFindings < Rule
      KIND = "sdp_violation"

      def list
        graph.sdp_violations.sort_by { |from, to| instability(from) - instability(to) }
                            .map { |from, to| violation_finding(from, to) }
      end

      private

      def violation_finding(from, to)
        finding(package: from, evidence: graph.evidence_for(from, to).to_a.first(5),
                message: "#{from} (I=#{label(from)}) depends on the LESS stable #{to} " \
                         "(I=#{label(to)}) — churn in #{to} will force churn in #{from}. " \
                         "Invert the edge or extract the stable part of #{to} that #{from} needs.")
      end

      def instability(package) = metrics[package].instability

      def label(package) = format("%.2f", instability(package))
    end
  end
end
