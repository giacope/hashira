# frozen_string_literal: true

require "prism"

class Hashira::Coupling::Declared
  HANDLERS = { irregular: [:irregular, nil], plural: %i[ruled plurals], singular: %i[ruled singulars] }
    .merge(uncountable: %i[added uncountables], acronym: %i[added acronyms]).freeze

  def initialize(tree)
    @tree = tree
  end

  def onto(table) = calls.reduce(table) { |current, call| handled(current, call) }

  private

  def calls = Hashira::Analysis::NodeWalk.collect(@tree).grep(Prism::CallNode).select { declares?(it) }

  def declares?(call) = HANDLERS.key?(call.name) && call.receiver

  def handled(table, call)
    handler, list = HANDLERS.fetch(call.name)
    __send__(handler, table, list, values(call))
  end

  def values(call) = Array(call.arguments&.arguments).flat_map { value(it) }

  def value(node)
    case node
    when Prism::ArrayNode then node.elements.flat_map { value(it) }
    when Prism::StringNode, Prism::SymbolNode then [Hashira::Analysis::Syntax.text(node)]
    else Array(expression(node))
    end
  end

  def expression(node)
    Regexp.new(node.unescaped, node.ignore_case? ? Regexp::IGNORECASE : 0) if node.is_a?(Prism::RegularExpressionNode)
  rescue RegexpError
    nil
  end

  def irregular(table, _list, (one, many)) = many ? table.irregular(one, many) : table

  def ruled(table, list, (rule, replacement))
    replacement ? table.with(list => [[pattern(rule), replacement]] + table.public_send(list)) : table
  end

  def added(table, list, words) = table.with(list => table.public_send(list) + words.grep(String))

  def pattern(rule) = rule.is_a?(Regexp) ? rule : /#{Regexp.escape(rule)}$/i
end
