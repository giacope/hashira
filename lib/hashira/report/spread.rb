# frozen_string_literal: true

class Hashira::Report::Spread
  def initialize(findings)
    @findings = findings
  end

  def to_a = (0...deepest).flat_map { |round| piles.filter_map { it[round] } }

  private

  def piles = @_piles ||= @findings.group_by(&:kind).values.map { ranked(it) }

  def deepest = piles.map(&:size).max.to_i

  def ranked(pile) = pile.each_with_index.sort_by { |finding, index| [-finding.magnitude.to_i, index] }.map(&:first)
end
