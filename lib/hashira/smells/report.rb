# frozen_string_literal: true

class Hashira::Smells::Report
  def initialize(project, trees)
    @types = Hashira::Smells::Census.new(project, trees).types
  end

  def findings = @findings ||= sniff(@types, judges) + sniff(@types.flat_map(&:defs), probes)

  private

  def sniff(subjects, checks) = subjects.flat_map { |subject| verdicts(subject, checks) }

  def verdicts(subject, checks) = checks.filter_map { |check| check.new(subject).finding }

  def judges
    [
      Hashira::Smells::DataClump, Hashira::Smells::InstanceVariableAssumption,
      Hashira::Smells::ModuleInitialize, Hashira::Smells::RepeatedConditional,
      Hashira::Smells::TooManyInstanceVariables
    ]
  end

  def probes
    [
      Hashira::Smells::ControlParameter, Hashira::Smells::DuplicateMethodCall,
      Hashira::Smells::FeatureEnvy, Hashira::Smells::ManualDispatch,
      Hashira::Smells::NilCheck, Hashira::Smells::UtilityFunction
    ]
  end
end
