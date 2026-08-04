# frozen_string_literal: true

require_relative "../pipeline"

module Hashira::CLI::FailOn
  MEASURES = (Hashira::Pipeline::ANALYZERS - %i[coupling smells]).map(&:to_s).freeze

  KINDS = {
    "cycles" => "cycle", "sdp" => "sdp_violation", "dupe" => "duplication",
    **Hashira::Pipeline::STRUCTURAL.to_h { [it, it] },
    **MEASURES.to_h { [it, it] },
    "smells" => Hashira::Pipeline::SMELLS, **Hashira::Pipeline::SMELLS.to_h { [it, it] }
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
