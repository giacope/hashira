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

  def initialize(subject, rules, callers)
    super(subject, rules)
    @callers = callers
  end

  private

  def smelly? = !subject.standing.in?(HIDDEN) && culprits.any?

  def culprits = @_culprits ||= subject.accept(Hashira::Smells::Parameters).names.flat_map { |name| culprit(name) }

  def culprit(name)
    lines = spots(name).uniq.sort
    lines.empty? || !picks.picked?(name) ? [] : [[name, lines]]
  end

  def picks = @_picks ||= subject.accept(Hashira::Smells::Picks, @callers.of(subject))

  def spots(name)
    subject.accept(Hashira::Smells::ParamCheck, name).matches.map { it.location.start_line }
  end

  def detail = Steering.new(site, culprits.map { |name, _lines| name })

  def evidence = culprits.map { |name, lines| tally(name, lines) }
end
