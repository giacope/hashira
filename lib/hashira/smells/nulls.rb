# frozen_string_literal: true

require "prism"
require_relative "tails"

class Hashira::Smells::Nulls
  PICKS = %i[find detect first last [] dig min_by max_by find_by find_index index presence].freeze

  OPEN = { Prism::IfNode => :subsequent, Prism::UnlessNode => :else_clause, Prism::CaseNode => :else_clause }.freeze

  FLOW = Hashira::Smells::Tails.new(Hashira::Smells::Tails::FLOW)

  def initialize(trees)
    @trees = trees
  end

  def answer?(path, name) = index.fetch("#{path}##{name}", []).any? { nullable?(it) }

  private

  def index
    @_index ||= @trees.flat_map { defs(it) }.group_by(&:first).transform_values { it.map(&:last) }
  end

  def defs(tree)
    found = []
    Hashira::Analysis::TypeWalk.new(tree).walk do |node, full|
      Hashira::Analysis::TypeWalk.new(node).sections.each do |definition, section|
        next if definition.receiver || section == :singleton
        found << ["#{full.join("::")}##{definition.name}", definition]
      end
    end
    found
  end

  def nullable?(definition)
    held = Hashira::Analysis::Syntax.new(definition).statements.compact
    held.empty? || returns?(definition) || FLOW.reach(held.last(1)).any? { open?(it) }
  end

  def returns?(definition)
    Hashira::Smells::Scope.new(definition).inside.grep(Prism::ReturnNode).any? { bare?(it.arguments) }
  end

  def bare?(arguments) = Array(arguments&.arguments).all?(Prism::NilNode)

  def open?(node)
    case node
    when Prism::NilNode then true
    when Prism::CallNode then node.safe_navigation? || PICKS.include?(node.name)
    else OPEN.key?(node.class) && node.public_send(OPEN.fetch(node.class)).nil?
    end
  end
end
