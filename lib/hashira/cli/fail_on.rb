# frozen_string_literal: true

require_relative "../pipeline"
require_relative "kinds"

module Hashira::CLI::FailOn
  MEASURES = (Hashira::Pipeline::ANALYZERS - %i[coupling smells]).map(&:to_s).freeze

  EVERY = "all"

  KINDS = { "cycles" => "cycle", "sdp" => "sdp_violation", "dupe" => "duplication" }
    .merge(Hashira::Pipeline::STRUCTURAL.to_h { [it, it] })
    .merge(MEASURES.to_h { [it, it] })
    .merge(%w[fragmentation indirection].to_h { [it, it] })
    .merge("smells" => Hashira::Pipeline::SMELLS)
    .merge(Hashira::Pipeline::SMELLS.to_h { [it, it] })
    .freeze

  OWNERS = {
    **Hashira::Pipeline::STRUCTURAL.to_h { [it, :coupling] },
    **MEASURES.to_h { [it, it.to_sym] },
    **%w[fragmentation indirection].to_h { [it, :complexity] },
    **Hashira::Pipeline::SMELLS.to_h { [it, :smells] }
  }.freeze

  module_function

  def parse(list)
    kinds = Hashira::CLI::Kinds.new("--fail-on", KINDS.merge(EVERY => EVERY)).parse(list)
    kinds.include?(EVERY) ? [EVERY] : kinds
  end

  def named(kinds) = kinds - [EVERY]

  def gated(kinds, checked) = kinds.include?(EVERY) ? checked : kinds

  def owner(kind) = OWNERS.fetch(kind)
end
