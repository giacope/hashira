# frozen_string_literal: true

require "prism"

class Hashira::Smells::ManualDispatch < Hashira::Smells::Check
  PROTOCOL = :respond_to_missing?

  PROXY = :method_missing

  PROBE = "respond_to?"

  TYPED = "a type check"

  STATUSED = "a status switch"

  private

  def smelly? = subject.node.name != PROTOCOL && (probes.any? || switches.any?)

  def probes = @_probes ||= proxy? ? [] : sightings.map { probe(it) }.reject(&:excused?)

  def proxy? = subject.node.name == PROXY && subject.neighbors.include?(PROTOCOL)

  def sightings
    Hashira::Smells::Scope.inside(subject.node).select { it.is_a?(Prism::CallNode) && it.name == :respond_to? }
  end

  def probe(call) = Hashira::Smells::Probe.new(call, subject, foreign)

  def foreign = @_foreign ||= Hashira::Smells::Foreign.new(subject, subject.ownership)

  def switchboard = @_switchboard ||= Hashira::Smells::Switches.new(subject.node, subject.ownership)

  def switches = switchboard.typed + switchboard.statuses

  def via = { PROBE => probes, TYPED => switchboard.typed, STATUSED => switchboard.statuses }.reject { _2.empty? }.keys

  def lines = (probes.map(&:line) + switches.flat_map(&:lines)).uniq.sort

  def detail = { site: "#{subject.file}:#{lines.join(", ")}", via: }

  def evidence = probes.map { tally(it.shown, [it.line]) } + switches.map { tally(switched(it), it.lines) }

  def switched(switch) = "#{switch.subject}: #{switch.labels.join(", ")}"

  def rating = probes.any? && switches.none? && probes.all?(&:trusted?) ? { confidence: :high } : {}
end
