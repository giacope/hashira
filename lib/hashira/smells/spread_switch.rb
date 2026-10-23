# frozen_string_literal: true

class Hashira::Smells::SpreadSwitch
  KIND = "manual_dispatch"

  SPREAD = 3

  Sighting = Data.define(:definition, :arm)

  def initialize(whole)
    @whole = whole
  end

  def finding
    return if spread.empty?
    Hashira::Analysis::Finding.new(kind: KIND, package: @whole.subject, detail:, evidence:, anchors:)
  end

  def detail
    file = spread.first.definition.file
    { site: "#{file}:#{lines(file).join(", ")}", via: ["a type check spread over #{methods} methods"] }
  end

  def anchors = spread.map { site(it) }.uniq

  def evidence = spread.map { row(it) }

  private

  def spread = @_spread ||= sightings.group_by { key(it) }.values.select { wide?(it) }.flatten(1)

  def sightings
    @whole.owned.reject { Hashira::Smells::ManualDispatch::COMPARISONS.include?(it.node.name) }.flat_map do |definition|
      Hashira::Smells::Switches.new(definition.node, definition.ownership, definition.owner).held.map { Sighting.new(definition, it) }
    end
  end

  def key(sighting) = [sighting.arm.subject.slice, sighting.arm.label]

  def wide?(group) = group.uniq(&:definition).size >= SPREAD

  def methods = spread.uniq(&:definition).size

  def lines(file) = spread.select { it.definition.file == file }.map { it.arm.line }.uniq.sort

  def site(sighting) = "#{sighting.definition.file}:#{sighting.arm.line}"

  def row(sighting)
    arm = sighting.arm
    "#{sighting.definition.subject}: #{arm.subject.slice} is #{arm.label} (#{site(sighting)})"
  end
end
