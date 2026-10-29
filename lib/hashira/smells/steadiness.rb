# frozen_string_literal: true

require "prism"

class Hashira::Smells::Steadiness
  MINTS = %i[new dup clone allocate rand srand generate].freeze

  SOURCES = %w[SecureRandom Random].freeze

  LITERALS = [
    Prism::StringNode, Prism::SymbolNode, Prism::ArrayNode, Prism::HashNode,
    Prism::IntegerNode, Prism::FloatNode, Prism::RegularExpressionNode
  ].freeze

  MATCHES = [Prism::NumberedReferenceReadNode, Prism::BackReferenceReadNode].freeze

  MATCHED = %i[$~ $LAST_MATCH_INFO].freeze

  def initialize(discards)
    @discards = discards
  end

  def steady?(node) = !(@discards.include?(node) || fresh?(node) || volatile?(node) || raises?(node))

  private

  def raises?(node) = Hashira::Smells::Exits.new(node).raise?

  def fresh?(node) = minted?(node) || fed(node).any? { minted?(it) }

  def fed(node) = Array(node.arguments).flat_map { beneath(it) }.grep(Prism::CallNode)

  def beneath(node) = [node] + Hashira::Smells::Scope.new(node).inside

  def minted?(node) = MINTS.include?(node.name) || Hashira::Smells::Message.new(node).draws? || spawns?(node.receiver)

  def spawns?(receiver) = LITERALS.include?(receiver.class) || SOURCES.include?(receiver&.slice)

  def volatile?(node) = beneath(node).any? { matched?(it) }

  def matched?(node)
    case node
    when *MATCHES then true
    when Prism::GlobalVariableReadNode then MATCHED.include?(node.name)
    else node.is_a?(Prism::CallNode) && node.name == :last_match && node.receiver&.slice == "Regexp"
    end
  end
end
