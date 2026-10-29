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

  def initialize(
    subject, rules, foreign = Hashira::Smells::Foreign.new(subject, subject.ownership),
    switchboard = Hashira::Smells::Switches.new(subject.node, subject.ownership, subject.owner)
  )
    super(subject, rules)
    @foreign = foreign
    @switchboard = switchboard
  end

  private

  def smelly? = !protocol?(subject.node.name) && (probes.any? || switches.any?)

  def protocol?(name) = name == PROTOCOL || COMPARISONS.include?(name)

  def probes = @_probes ||= proxy? ? [] : sightings.map { probe(it) }.reject(&:excused?)

  def proxy? = subject.node.name == PROXY && subject.neighbors.include?(PROTOCOL)

  def sightings
    Hashira::Smells::Scope.new(subject.node).inside.select { it.is_a?(Prism::CallNode) && it.name == :respond_to? }
  end

  def probe(call) = Hashira::Smells::Probe.new(call, subject, foreign)

  attr_reader :foreign, :switchboard

  def switches = switchboard.typed + switchboard.statuses

  def via = { PROBE => probes, TYPED => switchboard.typed, STATUSED => switchboard.statuses }.reject { _2.empty? }.keys

  def lines = (probes.map(&:line) + switches.flat_map(&:lines)).uniq.sort

  def detail = Dispatch.new("#{subject.file}:#{lines.join(", ")}", via)

  def evidence = probes.map { tally(it.shown, [it.line]) } + switches.map { tally(it.to_s, it.lines) }

  def ratings = probes.any? && switches.none? && probes.all?(&:trusted?) ? [:high] : []
end
