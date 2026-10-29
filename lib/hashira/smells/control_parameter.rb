# frozen_string_literal: true

class Hashira::Smells::ControlParameter < Hashira::Smells::Check
  HIDDEN = %i[private protected].freeze

  private

  def smelly? = !HIDDEN.include?(subject.section) && culprits.any?

  def culprits = @_culprits ||= subject.parameters.flat_map { |name| culprit(name) }

  def culprit(name)
    lines = spots(name).uniq.sort
    lines.empty? || !picks.picked?(name) ? [] : [[name, lines]]
  end

  def picks = @_picks ||= Hashira::Smells::Picks.new(subject.node, subject.ownership.callers.of(subject))

  def spots(name)
    Hashira::Smells::ParamCheck.new(subject.node, name).matches.map { it.location.start_line }
  end

  def detail = { site:, names: culprits.map { |name, _lines| name } }

  def evidence = culprits.map { |name, lines| tally(name, lines) }
end
