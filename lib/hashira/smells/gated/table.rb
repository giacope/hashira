# frozen_string_literal: true

require "prism"

class Hashira::Smells::Gated::Table
  CHAINED = %i[freeze merge].freeze

  HASHES = [Prism::HashNode, Prism::KeywordHashNode].freeze

  def initialize(write)
    @write = write
  end

  def name = @write.name

  def line = @write.location.start_line

  def sealed? = frozen? && !pairs.empty?

  def dispatch? = sealed? && pairs.all? { it.value.is_a?(Prism::SymbolNode) }

  def handlers = pairs.map { [it.key.slice, it.value.unescaped.to_sym] }

  private

  def frozen?
    value = @write.value
    value.is_a?(Prism::CallNode) && value.name == :freeze
  end

  def pairs = @_pairs ||= elements(unwrap(@write.value))

  def elements(hashes)
    found = hashes&.flat_map(&:elements)
    found&.all?(Prism::AssocNode) ? found : []
  end

  def unwrap(node)
    return [node] if hash?(node)
    chained(node) if node.is_a?(Prism::CallNode)
  end

  def hash?(node) = HASHES.include?(node.class)

  def chained(node)
    base = unwrap(node.receiver)
    added = given(node)
    base + added if base && linked?(node.name) && added.all? { hash?(it) }
  end

  def linked?(call) = CHAINED.include?(call)

  def given(node) = node.arguments&.arguments || []
end
