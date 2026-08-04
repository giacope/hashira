# frozen_string_literal: true

class Hashira::Smells::ControlParameter < Hashira::Smells::Check
  private

  def smelly? = culprits.any?

  def culprits = @culprits ||= subject.parameters.filter_map { |name| culprit(name) }

  def culprit(name)
    lines = spots(name).uniq
    [name, lines] unless lines.empty?
  end

  def spots(name)
    Hashira::Smells::ParamCheck.new(subject.node, name).matches.map { it.location.start_line }
  end

  def detail = { site:, names: culprits.map { |name, _lines| name } }

  def evidence = culprits.map { |name, lines| tally(name, lines) }
end
