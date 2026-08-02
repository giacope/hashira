# frozen_string_literal: true

module Hashira::CLI::FailOn
  SMELLS = %w[
    control_parameter data_clump duplicate_method_call feature_envy instance_variable_assumption
    manual_dispatch module_initialize nil_check repeated_conditional too_many_instance_variables
    utility_function
  ].freeze

  KINDS = {
    "cycles" => "cycle", "cycle" => "cycle",
    "sdp" => "sdp_violation", "sdp_violation" => "sdp_violation",
    "complexity" => "complexity",
    "duplication" => "duplication", "dupe" => "duplication",
    "smells" => SMELLS, **SMELLS.to_h { [it, it] }
  }.freeze

  module_function

  def parse(list)
    return [] unless list
    list.split(",").flat_map { Array(kind(it.strip)) }.uniq
  end

  def kind(name)
    KINDS.fetch(name) do
      raise(Hashira::Error, "unknown --fail-on kind #{name.inspect} (use: #{KINDS.keys.join(", ")})")
    end
  end
end
