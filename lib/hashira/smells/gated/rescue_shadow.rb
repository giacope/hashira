# frozen_string_literal: true

require "prism"
require_relative "rule"
require_relative "shade"

class Hashira::Smells::Gated::RescueShadow < Hashira::Smells::Gated::Rule
  REQUIRES = %i[no_const_missing no_eval].freeze

  private

  def considers?(_type) = true

  def subjects(type) = type.defs.flat_map { shadows(it) }

  def shadows(method) = heads(method).flat_map { covered(method, it) }

  def heads(method)
    clauses = Hashira::Smells::Scope.inside(method.node).grep(Prism::RescueNode)
    trailing = Set.new.compare_by_identity.merge(clauses.filter_map(&:subsequent))
    clauses.reject { trailing.include?(it) }
  end

  def covered(method, head)
    caught = []
    chain(head).flat_map { |clause| buried(method, caught, clause).tap { caught += clause.exceptions } }
  end

  def buried(method, caught, clause)
    clause.exceptions.filter_map { shadowed(method, caught, it) }
  end

  def chain(head)
    rest = head.subsequent
    rest ? [head, *chain(rest)] : [head]
  end

  def shadowed(method, caught, node)
    wider = caught.find { hides?(it, node) }
    Hashira::Smells::Gated::Shade.new(host: method, later: node, wider:) if wider
  end

  def hides?(earlier, later)
    path = Hashira::Analysis::Syntax.segments(earlier).join("::")
    !path.empty? && reaches?(path, later)
  end

  def reaches?(path, later) = matched?(path, Hashira::Analysis::Syntax.segments(later))

  def matched?(path, segments)
    return false if segments.empty?
    written(segments) == path || inherits?(path, segments)
  end

  def written(segments) = segments.join("::")

  def inherits?(path, segments)
    kin = family.lone(segments)
    kin && family.ascent(kin).any? { family.kindred?(it, path) }
  end

  def entry(_type, shade) = finding(**shade.parts)
end
