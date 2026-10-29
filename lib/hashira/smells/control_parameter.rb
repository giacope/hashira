# frozen_string_literal: true

class Hashira::Smells::ControlParameter < Hashira::Smells::Check
  HIDDEN = %i[private protected].freeze

  class Steering
    def initialize(site, names)
      @site = site
      @names = names
    end

    def to_h = { site: @site, names: @names }

    def phrase(package)
      "#{package} is steered by #{Hashira::Prose::Quoted.new(@names)} (#{@site}). " \
        "Split the method, or pass a strategy instead of a flag."
    end
  end

  private

  def smelly? = !HIDDEN.include?(subject.section) && culprits.any?

  def culprits = @_culprits ||= subject.parameters.flat_map { |name| culprit(name) }

  def culprit(name)
    lines = spots(name).uniq.sort
    lines.empty? || !picks.picked?(name) ? [] : [[name, lines]]
  end

  def picks = Hashira::Smells::Picks.new(subject.node, subject.ownership.callers.of(subject))

  def spots(name)
    Hashira::Smells::ParamCheck.new(subject.node, name).matches.map { it.location.start_line }
  end

  def detail = Steering.new(site, culprits.map { |name, _lines| name })

  def evidence = culprits.map { |name, lines| tally(name, lines) }
end
