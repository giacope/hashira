# frozen_string_literal: true

require "prism"
require_relative "comparisons"

class Hashira::Smells::ManualDispatch < Hashira::Smells::Check
  PROTOCOL = :respond_to_missing?

  COMPARISONS = Hashira::Smells::Comparisons.new

  PROXY = :method_missing

  PROBE = "respond_to?"

  TYPED = "a type check"

  STATUSED = "a status switch"

  class Dispatch
    DUCK = "Trust the duck type, or split the callers into two adapters."

    SWITCH = "Move each branch onto the type or state it tests, and let polymorphism pick."

    def initialize(site, via)
      @site = site
      @via = via
    end

    def to_h = { site: @site, via: @via }

    def phrase(package)
      "#{package} dispatches manually via #{@via.join(" and ")} (#{@site}). #{@via == [PROBE] ? DUCK : SWITCH}"
    end
  end

  private

  def initialize(subject, rules, probing, switchboard)
    super(subject, rules)
    @probing = probing
    @switchboard = switchboard
  end

  def smelly? = !protocol?(name) && (probes.any? || switches.any?)

  def protocol?(name) = name == PROTOCOL || COMPARISONS.include?(name)

  def probes = @_probes ||= proxy? ? [] : @probing.of(sightings).reject(&:excused?)

  def proxy? = name == PROXY && subject.home.neighbors.include?(PROTOCOL)

  def name = subject.accept(Hashira::Smells::Signature).name

  def sightings
    subject.accept(Hashira::Smells::Scope).inside.select { it.is_a?(Prism::CallNode) && it.name == :respond_to? }
  end

  attr_reader :switchboard

  def switches = switchboard.typed + switchboard.statuses

  def via = { PROBE => probes, TYPED => switchboard.typed, STATUSED => switchboard.statuses }.reject { _2.empty? }.keys

  def lines = (probes.map(&:line) + switches.flat_map(&:lines)).uniq.sort

  def detail = Dispatch.new(subject.spot.at(lines), via)

  def evidence = probes.map { tally(it.shown, [it.line]) } + switches.map { tally(it.to_s, it.lines) }

  def ratings = probes.any? && switches.none? && probes.all?(&:trusted?) ? [:high] : []
end
