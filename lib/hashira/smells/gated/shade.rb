# frozen_string_literal: true

require "prism"

module Hashira
  module Smells
    module Gated
      Shade =
        Data.define(:host, :later, :wider) do
          def parts
            { package: host.subject, sources: [host.file] }
              .merge(evidence: [quote], detail: { site: at(later), names: [later.slice], owners: [wider.slice] })
          end

          def quote = "#{at(wider)}: rescue #{wider.slice}"

          def at(node) = "#{host.file}:#{node.location.start_line}"
        end
    end
  end
end
