# frozen_string_literal: true

require "prism"

module Hashira
  module Smells
    module Gated
      Dispatch =
        Data.define(:type, :table, :routes) do
          def routed? = !routes.empty?

          def entries = (table.handlers + fallbacks).uniq

          def owner = type.name

          def registry = "#{type.name}::#{table.name}"

          def site = "#{type.file}:#{table.line}"

          def file = type.file

          def gap(absent)
            { package: registry, sources: [file] }
              .merge(evidence: absent.map { "#{it.first} → ##{it.last}" }, detail: detail(absent))
          end

          def detail(absent) = { site:, owner:, names: absent.map(&:last) }

          def fallbacks = routes.filter_map { spare(it) }

          def spare(read)
            last = (read.arguments&.arguments || []).last
            ["(missing key)", last.unescaped.to_sym] if read.name == :fetch && last.is_a?(Prism::SymbolNode)
          end
        end
    end
  end
end
