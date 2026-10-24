# frozen_string_literal: true

require_relative "boundary_sprawl"
require_relative "check"
require_relative "concrete_inheritance"
require_relative "data_class"
require_relative "exports"
require_relative "heirs"
require_relative "bequests"
require_relative "hierarchy"
require_relative "attributes"
require_relative "factory"
require_relative "grouping"
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
require_relative "nil_check"
require_relative "ownership"
require_relative "repeated_conditional"
require_relative "spread_switch"
require_relative "state_sprawl"
require_relative "utility_function"

class Hashira::Smells::Report
  CHECKS = Hashira::Smells::Check.subclasses.sort_by(&:name).freeze

  JUDGES = [
    Hashira::Smells::DataClump, Hashira::Smells::AssumedState,
    Hashira::Smells::ModuleInitialize, Hashira::Smells::RepeatedConditional,
    Hashira::Smells::StateSprawl, Hashira::Smells::ConcreteInheritance, Hashira::Smells::RefusedBequest,
    Hashira::Smells::LowCohesion, Hashira::Smells::DataClass, Hashira::Smells::MiddleMan
  ].freeze

  PROBES = (CHECKS - JUDGES).freeze

  def initialize(project, trees, boundaries, rules)
    @project = project
    @trees = trees
    @boundaries = boundaries
    @rules = rules
  end

  def findings = @_findings ||= sniff(wholes, wanted(JUDGES)) + sniff(methods, wanted(PROBES)) + spread + sprawl

  private

  def census = @_census ||= Hashira::Smells::Census.new(@project, @trees)

  def types = @_types ||= census.types

  def wholes
    @_wholes ||= types.group_by(&:name).values.map { Hashira::Smells::Whole.new(openings: it, family:) }
  end

  def family = @_family ||= Hashira::Smells::Hierarchy.new(types)

  def methods = types.flat_map(&:defs)

  def spread
    return [] unless wants?(Hashira::Smells::SpreadSwitch::KIND)
    wholes.select { it.kind == :class }.filter_map { Hashira::Smells::SpreadSwitch.new(it).finding }
  end

  def wanted(checks) = checks.select { wants?(Hashira::Smells::Kind.new(it).to_s) }

  def wants?(kind) = @rules.enabled?(kind)

  def sprawl
    return [] unless wants?(Hashira::Smells::BoundarySprawl::KIND)
    Hashira::Smells::BoundarySprawl.new(methods, census.ownership, @boundaries.interpreted, @rules).findings
  end

  def sniff(subjects, checks)
    subjects.flat_map { |subject| checks.filter_map { |check| check.new(subject, @rules).finding } }
  end
end
