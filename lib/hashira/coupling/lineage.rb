# frozen_string_literal: true

require "prism"

class Hashira::Coupling::Lineage
  MIXINS = %i[include prepend].freeze

  Link =
    Data.define(:segments, :nesting) do
      def reach = segments.length
    end

  def initialize(definitions)
    @definitions = definitions
  end

  def parents(path) = links.fetch(path, [])

  private

  def links
    @_links ||=
      @definitions.select(&:type?).group_by(&:path).transform_values do |openings|
        openings.flat_map { [ancestor(it), *mixins(it)].compact }
      end
  end

  def ancestor(definition) = (link(definition.superclass, definition.scope[...-1]) if definition.klass?)

  def mixins(definition)
    calls = syntax(definition.node).statements.grep(Prism::CallNode).select { mixin?(it) }
    calls.flat_map { it.arguments.arguments }.map { link(it, definition.scope) }
  end

  def mixin?(call) = MIXINS.include?(call.name) && !call.receiver && call.arguments

  def link(node, nesting)
    read = syntax(node)
    return unless read.static?
    Link.new(segments: read.segments, nesting: read.rooted? ? [] : nesting)
  end

  def syntax(node) = Hashira::Analysis::Syntax.new(node)
end
