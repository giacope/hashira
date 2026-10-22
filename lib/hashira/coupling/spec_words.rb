# frozen_string_literal: true

require "prism"

class Hashira::Coupling::SpecWords
  MATCHERS = { "be" => "%s?", "have" => "has_%s?" }.freeze

  MATCHER = /\A(be|have)_(?:an?_)?([a-z]\w*)\z/

  HELPERS = %i[let let! let_it_be subject given given!].freeze

  def initialize(tree)
    @tree = tree
  end

  def to_a
    nodes.flat_map do |node|
      case node
      when Prism::CallNode then node.name.to_s.then { [(it unless node.variable_call?), matched(it)] }
      when Prism::SymbolNode then named.include?(node) ? [] : [Hashira::Analysis::Syntax.new(node).text]
      when Prism::ConstantReadNode, Prism::ConstantPathNode then [node.name.name]
      else []
      end
    end.compact
  end

  private

  def nodes = @_nodes ||= Hashira::Analysis::NodeWalk.new(@tree).collect

  def matched(name) = name.match(MATCHER)&.then { format(MATCHERS.fetch(it[1]), it[2]) }

  def named
    @_named ||= Set.new.compare_by_identity.merge(
      nodes.grep(Prism::CallNode).select { HELPERS.include?(it.name) && !it.receiver }
        .filter_map { it.arguments&.arguments&.first }
    )
  end
end
