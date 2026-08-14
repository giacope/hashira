# frozen_string_literal: true

require_relative "boundary_sprawl"
require_relative "check"
require_relative "control_parameter"
require_relative "data_clump"
require_relative "duplicate_method_call"
require_relative "feature_envy"
require_relative "foreign"
require_relative "instance_variable_assumption"
require_relative "kind"
require_relative "manual_dispatch"
require_relative "module_initialize"
require_relative "nil_check"
require_relative "ownership"
require_relative "repeated_conditional"
require_relative "too_many_instance_variables"
require_relative "utility_function"

class Hashira::Smells::Report
  CHECKS = Hashira::Smells::Check.subclasses.sort_by(&:name).freeze

  JUDGES = [
    Hashira::Smells::DataClump, Hashira::Smells::InstanceVariableAssumption,
    Hashira::Smells::ModuleInitialize, Hashira::Smells::RepeatedConditional,
    Hashira::Smells::TooManyInstanceVariables
  ].freeze

  PROBES = (CHECKS - JUDGES).freeze

  def initialize(project, trees)
    @project = project
    @trees = trees
  end

  def findings = @findings ||= sniff(types, JUDGES) + sniff(methods, PROBES) + sprawl

  private

  def census = @census ||= Hashira::Smells::Census.new(@project, @trees)

  def types = @types ||= census.types

  def methods = types.flat_map(&:defs)

  def sprawl = Hashira::Smells::BoundarySprawl.new(methods, census.ownership).findings

  def sniff(subjects, checks) = subjects.flat_map { |subject| verdicts(subject, checks) }

  def verdicts(subject, checks) = checks.filter_map { |check| check.new(subject).finding }
end
