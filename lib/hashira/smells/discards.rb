# frozen_string_literal: true

require "prism"

class Hashira::Smells::Discards
  Slots =
    Data.define(:type, :names) do
      def of(node) = node.is_a?(type) ? names.flat_map { Array(node.public_send(it)) }.compact : []
    end

  TAILS = [
    Slots[Prism::IfNode, %i[statements subsequent]],
    Slots[Prism::UnlessNode, %i[statements else_clause]],
    Slots[Prism::ElseNode, %i[statements]],
    Slots[Prism::CaseNode, %i[conditions else_clause]],
    Slots[Prism::CaseMatchNode, %i[conditions else_clause]],
    Slots[Prism::WhenNode, %i[statements]],
    Slots[Prism::InNode, %i[statements]],
    Slots[Prism::BeginNode, %i[statements rescue_clause else_clause]],
    Slots[Prism::RescueNode, %i[statements subsequent]],
    Slots[Prism::EnsureNode, %i[statements]],
    Slots[Prism::ParenthesesNode, %i[body]],
    Slots[Prism::RescueModifierNode, %i[expression rescue_expression]],
    Slots[Prism::AndNode, %i[right]],
    Slots[Prism::OrNode, %i[right]],
    Slots[Prism::CallNode, %i[block]],
    Slots[Prism::BlockNode, %i[body]]
  ].freeze

  DROPS = [
    Slots[Prism::WhileNode, %i[statements]],
    Slots[Prism::UntilNode, %i[statements]],
    Slots[Prism::ForNode, %i[statements]],
    Slots[Prism::BeginNode, %i[ensure_clause]]
  ].freeze

  def initialize(root)
    @root = root
  end

  def include?(node) = voids.include?(node)

  private

  def voids = @_voids ||= Set.new.compare_by_identity.merge(dropped.flat_map { spread(it) })

  def dropped = Hashira::Smells::Scope.inside(@root).flat_map { thrown(it) }

  def thrown(node) = parts(node, DROPS) + sequence(node)[0...-1]

  def spread(node) = [node] + tails(node).flat_map { spread(it) }

  def tails(node) = parts(node, TAILS) + sequence(node).last(1)

  def sequence(node) = node.is_a?(Prism::StatementsNode) ? node.body : []

  def parts(node, table) = table.flat_map { it.of(node) }
end
