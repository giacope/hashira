# frozen_string_literal: true

module Hashira
  module Analysis
    CLONES = "duplication"

    MAGNITUDES = { "duplication" => :mass, "boundary_sprawl" => :count }
      .merge("complexity" => :cognitive, "indirection" => :chain, "fragmentation" => :helpers).freeze

    TRACKS = [/ \(lines? [\d, ]+\)/, /:[\d, -]+\z/, /:\d+(?=:)/].freeze

    Finding =
      Data.define(:kind, :package, :detail, :evidence, :cycle, :digest, :shape, :confidence, :anchors) do
        def initialize(cycle: nil, digest: nil, detail: nil, shape: nil, confidence: nil, anchors: [], **rest) = super

        def signature = "#{kind}:#{identity}"

        def heading = "#{kind}/#{package}"

        def magnitude = detail.to_h[MAGNITUDES[kind]]

        def identity = digest || package

        def trace
          "#{kind}|#{plain(site)}|#{told.join(";")}" unless digest
        end

        def told = evidence.empty? ? [shape].compact : evidence.map { plain(it) }

        def site = detail.to_h[:site].to_s

        def plain(text) = TRACKS.reduce(text) { |left, mark| left.gsub(mark, "") }

        def doubted? = confidence == :low

        def to_h = super.except(:shape, :confidence, :anchors).merge(detail: detail&.to_h).compact
      end
  end
end
