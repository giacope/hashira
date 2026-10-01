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
    @_links ||= @definitions.select(&:type?).group_by(&:path).transform_values { it.flat_map { heritage(it) } }
  end

  def heritage(definition) = [ancestor(definition), *mixins(definition)].compact

  def ancestor(definition) = (link(definition.superclass, outer(definition)) if definition.klass?)

  def outer(definition) = definition.scope[...-1]

  def mixins(definition) = included(definition).map { link(it, definition.scope) }

  def included(definition)
    syntax.statements(definition.node).grep(Prism::CallNode).select { mixin?(it) }.flat_map { it.arguments.arguments }
  end

  def mixin?(call) = MIXINS.include?(call.name) && !call.receiver && call.arguments

  def link(node, nesting)
    return unless syntax.static?(node)
    Link.new(segments: syntax.segments(node), nesting: syntax.rooted?(node) ? [] : nesting)
  end

  def syntax = Hashira::Analysis::Syntax
end
