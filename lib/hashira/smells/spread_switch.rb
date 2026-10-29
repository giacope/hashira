# frozen_string_literal: true

require_relative "comparisons"

class Hashira::Smells::SpreadSwitch
  KIND = "manual_dispatch"

  SPREAD = 3

  COMPARISONS = Hashira::Smells::Comparisons.new

  def initialize(whole)
    @whole = whole
  end

  def findings
    return [] if spread.empty?
    proof = Hashira::Analysis::Finding::Proof.new(evidence, anchors)
    [Hashira::Analysis::Finding.new(KIND, Hashira::Analysis::Finding::Name.new(@whole.subject), detail, proof)]
  end

  def detail
    file = spread.fetch(0).first.file
    Hashira::Smells::ManualDispatch::Dispatch.new(
      "#{file}:#{lines(file).join(", ")}", ["a type check spread over #{methods} methods"]
    )
  end

  def anchors = spread.map { site(it) }.uniq

  def evidence = spread.map { row(it) }

  private

  def spread = @_spread ||= sightings.group_by { key(it) }.values.select { wide?(it) }.flatten(1)

  def sightings
    @whole.owned.reject { COMPARISONS.include?(it.node.name) }.flat_map do |definition|
      Hashira::Smells::Switches.new(definition.node, definition.ownership, definition.owner).held.map { [definition, it] }
    end
  end

  def key((_definition, arm)) = [arm.topic, arm.label]

  def wide?(group) = group.uniq(&:first).size >= SPREAD

  def methods = spread.uniq(&:first).size

  def lines(file)
    held = spread.select { |definition, _arm| definition.file == file }
    held.map { |_definition, arm| arm.line }.uniq.sort
  end

  def site((definition, arm)) = "#{definition.file}:#{arm.line}"

  def row(sighting)
    definition, arm = sighting
    "#{definition.subject}: #{arm.topic} is #{arm.label} (#{site(sighting)})"
  end
end
