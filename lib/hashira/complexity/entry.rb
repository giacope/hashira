# frozen_string_literal: true

module Hashira
  module Complexity
    Entry =
      Data.define(:kind, :file, :site) do
        def finding(detail, helpers)
          Hashira::Analysis::Finding.new(
            kind:, package: site.subject, anchors: [spot], detail:,
            evidence: helpers.map { "#{it.name} (line #{it.location.start_line})" }
          )
        end

        def spot = "#{file}:#{site.node.location.start_line}"
      end
  end
end
