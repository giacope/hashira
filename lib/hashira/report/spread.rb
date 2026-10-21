# frozen_string_literal: true

class Hashira::Report::Spread
  STRUCTURAL = %w[
    cycle layer_violation sdp_violation mixed_audience wide_edge roll_call bidirectional_association dead_code
    change_coupling
  ].freeze

  LOCAL = %w[repeated_call duplication].freeze

  def initialize(findings)
    @findings = findings
  end

  def to_a = (0...deepest).flat_map { |round| piles.filter_map { it[round] } }

  private

  def piles
    @_piles ||=
      @findings.group_by(&:kind).each_with_index.sort_by { |(kind, _), at| [tier(kind), at] }
        .map { |(_, pile), _| ranked(pile) }
  end

  def tier(kind)
    return 0 if STRUCTURAL.include?(kind)
    LOCAL.include?(kind) ? 2 : 1
  end

  def deepest = piles.map(&:size).max.to_i

  def ranked(pile) = pile.each_with_index.sort_by { |finding, index| [order(finding), index] }.map(&:first)

  def order(finding) = [finding.doubted? ? 1 : 0, -finding.magnitude.to_i]
end
