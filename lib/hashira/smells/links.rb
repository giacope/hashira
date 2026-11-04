# frozen_string_literal: true

require "prism"

class Hashira::Smells::Links
  MIXINS = %i[include prepend].freeze

  MESSAGED = [Prism::CallNode, Prism::SymbolNode].freeze

  def initialize(typeset)
    @typeset = typeset
  end

  def pointed(type) = references(type).flat_map { @typeset.resolve(type.to_s, it) }

  def abroad(type) = references(type).select { @typeset.resolve(type.to_s, it).empty? }.map { it.join("::") }

  def mixins(type) = passed(type).flat_map { @typeset.resolve(type.to_s, segments(it)) }

  def messages(type)
    swept = @typeset.sweep(type)
    told = Set.new.compare_by_identity.merge(macros(type)).merge(swept.grep(Prism::AssocNode).map(&:key))
    swept.select { MESSAGED.include?(it.class) && !told.include?(it) }.map { message(type, it) }
  end

  private

  def references(type)
    (@_references ||= {}.compare_by_identity)[type] ||= passed(type).map { segments(it) } + supers(type)
  end

  def passed(type)
    calls = @typeset.sweep(type).grep(Prism::CallNode).reject(&:receiver).select(&:arguments)
    calls.select { MIXINS.include?(it.name) }.flat_map { it.arguments.arguments }
  end

  def supers(type) = type.accept(Hashira::Smells::Heading).then { it.written.empty? ? [] : [it.parent] }

  def segments(node) = Hashira::Analysis::Syntax.new(node).segments

  def macros(type) = type.accept(Hashira::Analysis::Syntax::Body).to_a.grep(Prism::CallNode).reject(&:receiver)

  def message(type, node)
    return [Hashira::Analysis::Syntax::Word.new(node).symbol, nil] if node.is_a?(Prism::SymbolNode)
    [node.name, addressee(type, node.receiver)]
  end

  def addressee(type, receiver)
    return type.to_s if Hashira::Smells::Origin.new(receiver).self?
    built = receiver.is_a?(Prism::CallNode) && receiver.name == :new
    found = segments(built ? receiver.receiver : receiver)
    @typeset.candidates(type.to_s, found).find { @typeset.known?(it) } || found if found.any?
  end
end
