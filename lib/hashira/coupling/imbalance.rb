# frozen_string_literal: true

require_relative "rule"

class Hashira::Coupling::Imbalance < Hashira::Coupling::Rule
  KIND = "unstable_dependency"

  class Gap
    def initialize(from, to, from_instability, to_instability)
      @from = from
      @to = to
      @from_instability = from_instability
      @to_instability = to_instability
    end

    def to_h = { from: @from, to: @to, from_instability: @from_instability, to_instability: @to_instability }

    def phrase(_package)
      "#{@from} (I=#{score(@from_instability)}) depends on the LESS stable #{@to} " \
        "(I=#{score(@to_instability)}) — churn in #{@to} will force churn in #{@from}. " \
        "Invert the edge or extract the stable part of #{@to} that #{@from} needs."
    end

    private

    def score(value) = format("%.2f", value)
  end

  def list
    ranked.map { |from, to| violation(from, to) }
  end

  private

  def ranked = graph.violations.sort_by { |from, to| instability(from) - instability(to) }

  def violation(from, to)
    sighted(from, Gap.new(from, to, instability(from), instability(to)), graph.evidence(from, to).to_a.first(5))
  end

  def instability(package) = metrics[package].instability
end
