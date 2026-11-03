# frozen_string_literal: true

require "prism"

class Hashira::Smells::Links
  MIXINS = %i[include prepend].freeze

  def initialize(typeset, bodies)
    @typeset = typeset
    @bodies = bodies
  end

  def pointed(type) = references(type).flat_map { @typeset.resolve(type.to_s, it) }

  def abroad(type) = references(type).select { @typeset.resolve(type.to_s, it).empty? }.map { it.join("::") }

  def mixins(type) = @bodies.passed(type, MIXINS).flat_map { @typeset.resolve(type.to_s, segments(it)) }

  def messages(type)
    swept = @bodies.sweep(type)
    told = Set.new.compare_by_identity.merge(macros(type)).merge(swept.grep(Prism::AssocNode).map(&:key))
    swept.reject { told.include?(it) }.flat_map { message(type, it) }
  end

  private

  def references(type) = @bodies.passed(type, MIXINS).map { segments(it) } + supers(type)

  def supers(type) = type.accept(Hashira::Smells::Heading).then { it.written.empty? ? [] : [it.parent] }

  def segments(node) = Hashira::Analysis::Syntax.new(node).segments

  def macros(type) = type.accept(Hashira::Analysis::Syntax::Body).to_a.grep(Prism::CallNode).reject(&:receiver)

  def message(type, node)
    case node
    when Prism::CallNode then [[node.name, addressee(type, node.receiver)]]
    when Prism::SymbolNode then [[Hashira::Analysis::Syntax::Word.new(node).symbol, nil]]
    else []
    end
  end

  def addressee(type, receiver)
    return type.to_s if Hashira::Smells::Origin.new(receiver).self?
    built = receiver.is_a?(Prism::CallNode) && receiver.name == :new
    found = segments(built ? receiver.receiver : receiver)
    @typeset.candidates(type.to_s, found).find { @typeset.known?(it) } || found if found.any?
  end
end
