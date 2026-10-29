# frozen_string_literal: true

module Hashira
  module Complexity
    Entry =
      Data.define(:kind, :file, :site) do
        def finding(detail, evidence)
          proof = Hashira::Analysis::Finding::Proof.new(evidence, [spot])
          Hashira::Analysis::Finding.new(kind, Hashira::Analysis::Finding::Name.new(site.subject), detail, proof)
        end

        def cite(node) = "#{node.name} (line #{node.location.start_line})"

        def spot = "#{file}:#{site.node.location.start_line}"
      end
  end
end
