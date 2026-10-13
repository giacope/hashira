# frozen_string_literal: true

module Hashira
  module Complexity
    Entry =
      Data.define(:kind, :file, :site) do
        def finding(detail, evidence)
          Hashira::Analysis::Finding.new(kind:, package: site.subject, anchors: [spot], detail:, evidence:)
        end

        def cite(node) = "#{node.name} (line #{node.location.start_line})"

        def spot = "#{file}:#{site.node.location.start_line}"
      end
  end
end
