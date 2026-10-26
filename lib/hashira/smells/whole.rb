# frozen_string_literal: true

module Hashira
  module Smells
    Whole =
      Data.define(:openings, :family) do
        def initialize(family: nil, **) = super

        def subject = first.name

        def kind = first.kind

        def site = first.site

        def assigned = first.assigned

        def heirs = first.heirs

        def claimed? = openings.any?(&:claimed)

        def owned = openings.flat_map(&:owned)

        def nodes = openings.map(&:node)

        def content = nodes.filter_map(&:body)

        def sweep = nodes.flat_map { Scope.new(it).sweep }

        def statements = nodes.flat_map { Hashira::Analysis::Syntax.new(it).statements }.compact

        def legible? = sweep.none? { Opaque.new([it]).any? }

        def first = openings.first
      end
  end
end
