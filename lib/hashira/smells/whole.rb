# frozen_string_literal: true

module Hashira
  module Smells
    Whole =
      Data.define(:openings) do
        def subject = first.name

        def kind = first.kind

        def site = first.site

        def assigned = first.assigned

        def heirs = first.heirs

        def owned = openings.flat_map(&:owned)

        def nodes = openings.map(&:node)

        def content = nodes.filter_map(&:body)

        def sweep = nodes.flat_map { Scope.sweep(it) }

        def first = openings.first
      end
  end
end
