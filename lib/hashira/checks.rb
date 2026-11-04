# frozen_string_literal: true

require_relative "coupling/report"
require_relative "smells/report"
require_relative "smells/kinds"

class Hashira::Checks
  include Enumerable

  STRUCTURAL = Hashira::Coupling::Rule.subclasses.sort_by(&:name).map { it::KIND }.freeze

  SMELLS = Hashira::Smells::Kinds.new.to_a.freeze

  OWNERS = {
    **STRUCTURAL.to_h { [it, :coupling] },
    "complexity" => :complexity, "duplication" => :duplication,
    "fragmentation" => :complexity, "indirection" => :complexity,
    **SMELLS.to_h { [it, :smells] }
  }.freeze

  ALIASES = { "cycles" => "cycle", "sdp" => "unstable_dependency", "sdp_violation" => "unstable_dependency" }
    .merge("dupe" => "duplication").freeze

  private_constant :STRUCTURAL, :SMELLS, :OWNERS, :ALIASES

  def initialize(owners = OWNERS)
    @owners = owners
  end

  def each(&) = @owners.keys.sort.each(&)

  def analyzers = @owners.values.uniq

  def owner(kind) = @owners.fetch(kind)

  def names
    smells, rest = @owners.keys.partition { owner(it) == :smells }
    ALIASES.merge(rest.to_h { [it, it] }).merge("smells" => smells).merge(smells.to_h { [it, it] })
  end
end
