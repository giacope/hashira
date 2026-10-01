# frozen_string_literal: true

require "prism"

class Hashira::Smells::Tails
  Slots =
    Data.define(:type, :names) do
      def of(node) = node.is_a?(type) ? names.flat_map { Array(node.public_send(it)) }.compact : []
    end

  FLOW = [
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
    Slots[Prism::OrNode, %i[right]]
  ].freeze

  def initialize(slots)
    @slots = slots
  end

  def reach(seeds) = Set.new.compare_by_identity.merge(seeds.flat_map { spread(it) })

  def parts(node) = @slots.flat_map { it.of(node) }

  private

  def sequence(node) = node.is_a?(Prism::StatementsNode) ? node.body : []

  def spread(node) = [node] + tails(node).flat_map { spread(it) }

  def tails(node) = parts(node) + sequence(node).last(1)
end
