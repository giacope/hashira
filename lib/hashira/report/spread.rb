# frozen_string_literal: true

class Hashira::Report::Spread
  STRUCTURAL = %w[
    cycle layer_violation unstable_dependency mixed_audience wide_edge roll_call bidirectional_association dead_code
    change_coupling
  ].freeze

  LOCAL = %w[repeated_call duplication].freeze

  def initialize(findings)
    @findings = findings
  end

  def to_a = (0...deepest).flat_map { |round| piles.filter_map { it[round] } }

  private

  def piles
    @_piles ||= kinds.each_with_index.sort_by { |(kind, _), at| [tier(kind), at] }.map { |(_, pile), _| ranked(pile) }
  end

  def kinds = @findings.group_by { it.to_h.fetch(:kind) }

  def tier(kind)
    return 0 if STRUCTURAL.include?(kind)
    LOCAL.include?(kind) ? 2 : 1
  end

  def deepest = piles.map(&:size).max.to_i

  def ranked(pile) = pile.each_with_index.sort_by { |finding, index| [finding, index] }.map(&:first)
end
