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

  def tested(node)
    case node
    when Prism::WhenNode then [chooser(node)]
    else sides(node).grep_v(Prism::NilNode)
    end
  end

  def chooser(arm) = cases.find { it.conditions.any? { it.equal?(arm) } }.predicate

  def cases = Hashira::Smells::Scope.inside(subject.node).grep(Prism::CaseNode)

  def inbound?(node) = tested(node).any? { foreign.entering?(it) }

  def foreign = @_foreign ||= Hashira::Smells::Foreign.new(subject, subject.ownership)

  def origin
    arriving = checks.count { inbound?(it) }
    return if arriving.zero?
    arriving == checks.size ? :outside : :both
  end

  def detail = { site: spots(checks), origin: }.compact
end
