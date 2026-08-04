# frozen_string_literal: true

require_relative "check"
require_relative "control_parameter"
require_relative "data_clump"
require_relative "duplicate_method_call"
require_relative "feature_envy"
require_relative "instance_variable_assumption"
require_relative "manual_dispatch"
require_relative "module_initialize"
require_relative "nil_check"
require_relative "repeated_conditional"
require_relative "too_many_instance_variables"
require_relative "utility_function"

class Hashira::Smells::Report
  CHECKS = Hashira::Smells::Check.subclasses.sort_by(&:name).freeze

  JUDGES = CHECKS.select(&:judge?).freeze

  PROBES = CHECKS.reject(&:judge?).freeze

  def initialize(project, trees)
    @types = Hashira::Smells::Census.new(project, trees).types
  end

  def findings = @findings ||= sniff(@types, JUDGES) + sniff(@types.flat_map(&:defs), PROBES)

  private

  def sniff(subjects, checks) = subjects.flat_map { |subject| verdicts(subject, checks) }

  def verdicts(subject, checks) = checks.filter_map { |check| check.new(subject).finding }
end
