# frozen_string_literal: true

require_relative "../pipeline"
require_relative "kinds"

module Hashira::CLI::FailOn
  MEASURES = (Hashira::Pipeline::ANALYZERS - %i[coupling smells]).map(&:to_s).freeze

  KINDS = { "cycles" => "cycle", "sdp" => "sdp_violation", "dupe" => "duplication" }
    .merge(Hashira::Pipeline::STRUCTURAL.to_h { [it, it] })
    .merge(MEASURES.to_h { [it, it] })
    .merge("smells" => Hashira::Pipeline::SMELLS)
    .merge(Hashira::Pipeline::SMELLS.to_h { [it, it] })
    .freeze

  OWNERS = {
    **Hashira::Pipeline::STRUCTURAL.to_h { [it, :coupling] },
    **MEASURES.to_h { [it, it.to_sym] },
    **Hashira::Pipeline::SMELLS.to_h { [it, :smells] }
  }.freeze

  module_function

  def parse(list) = Hashira::CLI::Kinds.new("--fail-on").parse(list)

  def owner(kind) = OWNERS.fetch(kind)
end
