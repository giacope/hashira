# frozen_string_literal: true

require "prism"

class Hashira::Coupling::Declared
  HANDLERS = %i[irregular plural singular uncountable acronym].to_set.freeze

  NONE = Hashira::Coupling::Inflections.new([], [], [], [])

  private_constant :NONE

  def initialize(tree)
    @tree = tree
  end

  def onto(table)
    calls = Hashira::Analysis::NodeWalk.new(@tree).collect.grep(Prism::CallNode).select { declares?(it) }
    calls.reduce(table) { |current, call| handled(current, call) }
  end

  private

  def declares?(call) = HANDLERS.include?(call.name) && call.receiver

  def handled(table, call) = table + __send__(call.name, Array(call.arguments&.arguments).flat_map { value(it) })

  def value(node)
    case node
    when Prism::ArrayNode then node.elements.flat_map { value(it) }
    when Prism::StringNode, Prism::SymbolNode then [Hashira::Analysis::Syntax::Word.new(node).to_s]
    when Prism::RegularExpressionNode then compiles?(node) ? [expression(node)] : []
    else []
    end
  end

  def expression(node) = Regexp.new(node.unescaped, node.ignore_case? ? Regexp::IGNORECASE : 0)

  def compiles?(node)
    expression(node)
    true
  rescue RegexpError
    false
  end

  def irregular((one, many)) = many ? Hashira::Coupling::Irregular.new(one, many).to_table : NONE

  def plural((rule, replacement))
    replacement ? Hashira::Coupling::Inflections.new(ruled(rule, replacement), [], [], []) : NONE
  end

  def singular((rule, replacement))
    replacement ? Hashira::Coupling::Inflections.new([], ruled(rule, replacement), [], []) : NONE
  end

  def uncountable(words) = Hashira::Coupling::Inflections.new([], [], words.grep(String), [])

  def acronym(words) = Hashira::Coupling::Inflections.new([], [], [], words.grep(String))

  def ruled(rule, replacement) = [[pattern(rule), replacement]]

  def pattern(rule) = rule.is_a?(Regexp) ? rule : /#{Regexp.escape(rule)}$/i
end
