# frozen_string_literal: true

require_relative "rule"

class Hashira::Coupling::SdpViolationFindings < Hashira::Coupling::Rule
  KIND = "sdp_violation"

  def list
    ranked.map { |from, to| violation(from, to) }
  end

  private

  def ranked = graph.violations.sort_by { |from, to| instability(from) - instability(to) }

  def violation(from, to)
    finding(package: from, evidence: graph.evidence(from, to).to_a.first(5), message: message(from, to))
  end

  def message(from, to)
    "#{from} (I=#{label(from)}) depends on the LESS stable #{to} " \
      "(I=#{label(to)}) — churn in #{to} will force churn in #{from}. " \
      "Invert the edge or extract the stable part of #{to} that #{from} needs."
  end

  def instability(package) = metrics[package].instability

  def label(package) = format("%.2f", instability(package))
end
