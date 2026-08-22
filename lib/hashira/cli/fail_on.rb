# frozen_string_literal: true

require_relative "../plan"

module Hashira::CLI::FailOn
  MEASURES = (Hashira::Plan::ANALYZERS - %i[coupling smells]).map(&:to_s).freeze

  KINDS = { "cycles" => "cycle", "sdp" => "sdp_violation", "dupe" => "duplication" }
    .merge(Hashira::Plan::STRUCTURAL.to_h { [it, it] })
    .merge(MEASURES.to_h { [it, it] })
    .merge("smells" => Hashira::Plan::SMELLS)
    .merge(Hashira::Plan::SMELLS.to_h { [it, it] })
    .freeze

  OWNERS = {
    **Hashira::Plan::STRUCTURAL.to_h { [it, :coupling] },
    **MEASURES.to_h { [it, it.to_sym] },
    **Hashira::Plan::SMELLS.to_h { [it, :smells] }
  }.freeze

  module_function

  def parse(list)
    return [] if list.to_s.empty?
    kinds = list.split(",").flat_map { Array(kind(it.strip)) }.uniq
    raise(Hashira::Error, "--fail-on needs at least one kind") if kinds.empty?
    kinds
  end

  def owner(kind) = OWNERS.fetch(kind)

  def kind(name)
    KINDS.fetch(name) do
      raise(Hashira::Error, "unknown --fail-on kind #{name.inspect} (use: #{KINDS.keys.join(", ")})")
    end
  end
end
