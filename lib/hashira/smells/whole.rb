# frozen_string_literal: true

module Hashira
  module Smells
    Whole =
      Data.define(:openings, :family) do
        def initialize(family: nil, **) = super

        def subject = first.name

        def kind = first.kind

        def site = home.site

        def home = openings.find { named?(it) } || largest

        def largest = openings.max_by { Analysis::Syntax.new(it.node).statements.compact.size }

        def named?(opening)
          short, long = [spelled(opening.file.delete_suffix(".rb"), "/"), spelled(subject, "::")].sort_by(&:size)
          long.last(short.size) == short
        end

        def spelled(text, separator) = text.downcase.delete("_").split(separator)

        def assigned = first.assigned

        def heirs = first.heirs

        def claimed? = openings.any?(&:claimed)

        def owned = openings.flat_map(&:owned)

        def nodes = openings.map(&:node)

        def content = nodes.filter_map(&:body)

        def sweep = nodes.flat_map { Scope.new(it).sweep }

        def first = openings.first
      end
  end
end
