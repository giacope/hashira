# frozen_string_literal: true

require "prism"

class Hashira::Coupling::Associations
  MACROS = %i[has_many has_one belongs_to has_and_belongs_to_many].freeze

  COLLECTIONS = %i[has_many has_and_belongs_to_many].freeze

  CONSTANT = /\A(?:::)?[A-Z]\w*(?:::[A-Z]\w*)*\z/

  class Target
    def initialize(name:, line:, guarantee:, macro:)
      @name = name
      @line = line
      @guarantee = guarantee
      @macro = macro
    end

    def sighting(nesting, scope) = [segments, @line, (nesting unless @name.start_with?("::")), scope, @macro]

    def pledges = @guarantee ? [["#{@line}: #{segments.join("::")}", "#{@line}: #{@guarantee}"]] : []

    private

    def segments = @name.delete_prefix("::").split("::")
  end

  def initialize(inflection)
    @inflection = inflection
  end

  def targets(node)
    return [] unless Hashira::Analysis::Syntax::Call.new(node).macro?(MACROS) && option(node, "polymorphic").none?(Prism::TrueNode)
    names = given(node).then { it.empty? ? inferred(node) : it }
    line = node.location.start_line
    names.grep(CONSTANT).map { Target.new(name: it, line:, guarantee: guarantee(node), macro: node.name) }
  end

  private

  def option(call, key) = Hashira::Analysis::Syntax::Value.new(call).given(key)

  def guarantee(call)
    dependent = option(call, "dependent").first
    return unless dependent.is_a?(Prism::SymbolNode)
    "#{call.name} #{call.arguments.arguments.first.slice}, dependent: #{dependent.slice}"
  end

  def given(call) = option(call, "class_name").grep(Prism::StringNode).map { words(it).first }

  def inferred(call)
    source = words(option(call, "source").first)
    base = (source + words(call.arguments.arguments.first)).first(1)
    base.map { COLLECTIONS.include?(call.name) || source.any? ? @inflection.classify(it) : @inflection.camelize(it) }
  end

  def words(node) = Hashira::Analysis::Syntax::Word.new(node).to_a.map(&:to_s)
end
