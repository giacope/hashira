# frozen_string_literal: true

require_relative "bags"
require_relative "readings"
require_relative "records"
require_relative "tuples"
require_relative "boundary_sprawl"
require_relative "check"
require_relative "member"
require_relative "testimony"
require_relative "concrete_inheritance"
require_relative "data_class"
require_relative "exports"
require_relative "hierarchy"
require_relative "attributes"
require_relative "factory"
require_relative "naming"
require_relative "refusal"
require_relative "values"
require_relative "low_cohesion"
require_relative "message_chain"
require_relative "middle_man"
require_relative "refused_bequest"
require_relative "control_parameter"
require_relative "data_clump"
require_relative "repeated_call"
require_relative "feature_envy"
require_relative "foreign"
require_relative "assumed_state"
require_relative "kind"
require_relative "manual_dispatch"
require_relative "module_initialize"
require_relative "opaque"
require_relative "origin"
require_relative "doubt"
require_relative "nil_check"
require_relative "ownership"
require_relative "repeated_conditional"
require_relative "spread_switch"
require_relative "state_sprawl"
require_relative "stateful_mixin"
require_relative "utility_function"

class Hashira::Smells::Report
  CHECKS = Hashira::Smells::Check.subclasses.sort_by(&:name).freeze

  JUDGES = [
    Hashira::Smells::DataClump, Hashira::Smells::AssumedState,
    Hashira::Smells::ModuleInitialize, Hashira::Smells::RepeatedConditional,
    Hashira::Smells::StateSprawl, Hashira::Smells::ConcreteInheritance, Hashira::Smells::RefusedBequest,
    Hashira::Smells::LowCohesion, Hashira::Smells::DataClass, Hashira::Smells::MiddleMan,
    Hashira::Smells::StatefulMixin
  ].freeze

  PROBES = (CHECKS - JUDGES).freeze

  SPREAD = "manual_dispatch"

  BAGS = "data_class"

  SPRAWL = "boundary_sprawl"

  def initialize(types, boundaries, rules, family = Hashira::Smells::Hierarchy.new(types))
    @types = types
    @boundaries = boundaries
    @rules = rules
    @family = family
  end

  def findings = @_findings ||= checks.flat_map(&:findings) + spread + sprawl + bags + gathered

  private

  attr_reader :types, :family

  def wholes
    @_wholes ||= types.group_by(&:name).values.map { Hashira::Smells::Whole.new(openings: it, family:) }
  end

  def methods = types.flat_map(&:defs)

  def spread
    return [] unless wants?(SPREAD)
    wholes.select { it.kind == :class }.flat_map { Hashira::Smells::SpreadSwitch.new(it).findings }
  end

  def wanted(checks) = checks.select { wants?(Hashira::Smells::Kind.new(it).to_s) }

  def wants?(kind) = @rules.enabled?(kind)

  def bags
    return [] unless @rules.strict? && wants?(BAGS)
    Hashira::Smells::Bags.new(types, family, methods).findings
  end

  def sprawl
    return [] unless wants?(SPRAWL)
    Hashira::Smells::BoundarySprawl.new(methods, @boundaries.interpreted, @rules).findings
  end

  def checks = @_checks ||= sniff(wholes, wanted(JUDGES)) + sniff(methods, wanted(PROBES))

  def sniff(subjects, kinds) = subjects.flat_map { |subject| kinds.map { it.build(subject, @rules) } }

  def gathered
    groups = checks.flat_map(&:members).reduce({}) { |found, member| member.gather(found) }
    groups.each_with_index.sort_by { |((section, _key), _member), index| [section, index] }
      .map { |(_key, member), _index| member.finding }
  end
end
