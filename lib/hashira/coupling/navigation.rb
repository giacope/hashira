# frozen_string_literal: true

require_relative "rule"

class Hashira::Coupling::Navigation < Hashira::Coupling::Rule
  KIND = "bidirectional_association"

  OWNING = %i[has_many has_one has_and_belongs_to_many].freeze

  def list = graph.pairs.map { |one, two| entry(one, two) }

  private

  def entry(one, two)
    parent, child = owning?(two, one) && !owning?(one, two) ? [two, one] : [one, two]
    sites = graph.declarations(parent, child) + graph.declarations(child, parent)
    finding(
      package: "#{one} ⇄ #{two}", evidence: sites, anchors: sites.map { it[/\A.+?:\d+/] },
      detail: { parent:, child:, guarantees: graph.guarantees(parent, child) }
    )
  end

  def owning?(from, to) = graph.declarations(from, to).any? { OWNING.include?(it.split(": ").last.split.first.to_sym) }
end
