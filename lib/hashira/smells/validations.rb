# frozen_string_literal: true

require "prism"

class Hashira::Smells::Validations
  OFF = [Prism::FalseNode, Prism::NilNode].freeze

  def initialize(home)
    @home = home
  end

  def validator?(name) = named(:validate).include?(name)

  def required?(attribute) = required.include?(attribute)

  private

  def required = @_required ||= (named(:validates_presence_of) + switched(:validates, :presence).first + owners).to_set

  def owners = switched(:belongs_to, :optional).last.flat_map { [it, keyed(it)] }

  def switched(macro, key) = macros(macro).partition { option?(it, key) }.map { |side| side.flat_map { symbols(it) } }

  def keyed(association) = :"#{association}_id"

  def named(macro) = macros(macro).flat_map { symbols(it) }

  def macros(name) = calls.select { it.name == name }

  def calls
    @_calls ||= Hashira::Analysis::Syntax.new(@home).statements.grep(Prism::CallNode).reject(&:receiver).select(&:arguments)
  end

  def symbols(call) = given(call).grep(Prism::SymbolNode).map { Hashira::Analysis::Syntax.new(it).text }.map(&:to_sym)

  def option?(call, key)
    options(call).any? { Hashira::Analysis::Syntax.new(it.key).symbol == key && !OFF.include?(it.value.class) }
  end

  def options(call) = Hashira::Analysis::Syntax.new(call).options.select { it.key.is_a?(Prism::SymbolNode) }

  def given(call) = call.arguments.arguments
end
