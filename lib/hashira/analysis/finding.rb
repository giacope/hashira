# frozen_string_literal: true

module Hashira
  module Analysis
    MAGNITUDES = { "complexity" => :cognitive, "duplication" => :mass, "boundary_sprawl" => :count }.freeze

    TRACKS = [/ \(lines? [\d, ]+\)/, /:[\d, -]+\z/, /:\d+(?=:)/].freeze

    Finding =
      Data.define(:kind, :package, :detail, :evidence, :cycle, :digest) do
        def initialize(cycle: nil, digest: nil, detail: nil, **rest) = super

        def signature = "#{kind}:#{identity}"

        def magnitude = detail.to_h[MAGNITUDES[kind]]

        def identity = digest || package

        def trace
          "#{kind}|#{plain(site)}|#{evidence.map { plain(it) }.join(";")}" unless digest
        end

        def site = detail.to_h[:site].to_s

        def plain(text) = TRACKS.reduce(text) { |left, mark| left.gsub(mark, "") }

        def to_h = super.merge(detail: detail&.to_h).compact
      end
  end
end
