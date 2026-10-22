# frozen_string_literal: true

require_relative "../pipeline"
require_relative "kinds"

module Hashira::CLI::FailOn
  MEASURES = (Hashira::Pipeline::ANALYZERS - %i[coupling smells]).map(&:to_s).freeze

  EVERY = "all"

  KINDS = { "cycles" => "cycle", "sdp" => "unstable_dependency", "sdp_violation" => "unstable_dependency" }
    .merge("dupe" => "duplication")
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
end
