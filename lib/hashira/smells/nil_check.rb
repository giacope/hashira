# frozen_string_literal: true

require "prism"

class Hashira::Smells::NilCheck < Hashira::Smells::Check
  EQUALITY = %i[== ===].freeze

  private

  def smelly? = checks.any?

  def checks = @_checks ||= Hashira::Smells::Scope.inside(subject.node).select { check?(it) }

  def check?(node)
    case node
    when Prism::CallNode then query?(node)
    when Prism::WhenNode then node.conditions.any?(Prism::NilNode)
    else false
    end
  end

  def query?(node)
    name = node.name
    name == :nil? || (EQUALITY.include?(name) && equated?(node))
  end

  def equated?(node) = sides(node).any?(Prism::NilNode)

  def sides(node) = [node.receiver] + (node.arguments&.arguments || [])

  def detail = { site: spots(checks) }
end
