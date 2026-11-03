# frozen_string_literal: true

require_relative "comparisons"

class Hashira::Smells::SpreadSwitch
  KIND = "manual_dispatch"

  SPREAD = 3

  COMPARISONS = Hashira::Smells::Comparisons.new

  def initialize(whole, names)
    @whole = whole
    @names = names
  end

  def findings
    return [] if spread.empty?
    proof = Hashira::Analysis::Finding::Proof.new(evidence, anchors)
    [Hashira::Analysis::Finding.new(KIND, Hashira::Analysis::Finding::Name.new(@whole.to_s), detail, proof)]
  end

  def detail
    file = spread.fetch(0).first.spot.to_s
    Hashira::Smells::ManualDispatch::Dispatch.new(
      "#{file}:#{lines(file).join(", ")}", ["a type check spread over #{methods} methods"]
    )
  end

  def anchors = spread.map { site(it) }.uniq

  def evidence = spread.map { row(it) }

  private

  def spread = @_spread ||= sightings.group_by { key(it) }.values.select { wide?(it) }.flatten(1)

  def sightings
    owned.reject { COMPARISONS.include?(it.accept(Hashira::Smells::Signature).name) }.flat_map do |definition|
      definition.accept(Hashira::Smells::Switches, @names, definition.home.to_s).held.map { [definition, it] }
    end
  end

  def owned = @whole.flat_map { it.reject { it.standing.singleton? } }

  def key((_definition, arm)) = [arm.topic, arm.label]

  def wide?(group) = group.uniq(&:first).size >= SPREAD

  def methods = spread.uniq(&:first).size

  def lines(file)
    held = spread.select { |definition, _arm| definition.spot.to_s == file }
    held.map { |_definition, arm| arm.line }.uniq.sort
  end

  def site((definition, arm)) = definition.spot.at([arm.line])

  def row(sighting)
    definition, arm = sighting
    "#{definition}: #{arm.topic} is #{arm.label} (#{site(sighting)})"
  end
end
