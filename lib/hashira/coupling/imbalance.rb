# frozen_string_literal: true

require_relative "rule"

class Hashira::Coupling::Imbalance < Hashira::Coupling::Rule
  KIND = "sdp_violation"

  Gap = Data.define(:from, :to, :from_instability, :to_instability)

  def list
    ranked.map { |from, to| violation(from, to) }
  end

  private

  def ranked = graph.violations.sort_by { |from, to| instability(from) - instability(to) }

  def violation(from, to)
    finding(package: from, evidence: graph.evidence(from, to).to_a.first(5), detail: detail(from, to))
  end

  def detail(from, to)
    Gap.new(from:, to:, from_instability: instability(from), to_instability: instability(to))
  end

  def instability(package) = metrics[package].instability
end
