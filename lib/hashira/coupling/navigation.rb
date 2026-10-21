# frozen_string_literal: true

require_relative "rule"

class Hashira::Coupling::Navigation < Hashira::Coupling::Rule
  KIND = "bidirectional_association"

  OWNING = %i[has_many has_one has_and_belongs_to_many].freeze

  def list
    linked = declared.keys.select { declared.key?(it.reverse) }.map(&:sort).uniq
    linked.map { oriented(*it) }.group_by(&:first).sort.map { |parent, found| entry(parent, found.map(&:last)) }
  end

  private

  def declared = @_declared ||= graph.associations.reject { it.from == it.to }.group_by { [it.from, it.to] }

  def oriented(one, two) = owning?(two, one) && !owning?(one, two) ? [two, one] : [one, two]

  def owning?(from, to) = declared[[from, to]].any? { OWNING.include?(it.macro.to_sym) }

  def entry(parent, children)
    links = ties(parent, children)
    finding(
      package: parent, evidence: links.map(&:said).uniq, anchors: links.map(&:anchor).uniq,
      detail: { parent:, children:, guarantees: links.filter_map { graph.pledges[it.site] }.uniq }
    )
  end

  def ties(parent, children)
    children.flat_map { declared[[parent, it]] }.sort_by(&:line) + children.flat_map { declared[[it, parent]] }
  end
end
