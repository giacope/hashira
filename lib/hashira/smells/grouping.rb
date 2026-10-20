# frozen_string_literal: true

class Hashira::Smells::Grouping
  CHAIN = "message_chain"

  ABSENT = "nil_check"

  OWNER = /[#.][^#.]+\z/

  def initialize(findings)
    @findings = findings
  end

  def findings = @findings.reject { grouped?(it) } + edges + sources

  private

  def grouped?(finding) = finding.kind == CHAIN || sourced?(finding)

  def sourced?(finding) = finding.kind == ABSENT && finding.detail[:sources].to_a.any?

  def edges = of(CHAIN).group_by { it.detail[:through] }.map { |through, group| edge(through, group) }

  def edge(through, group) = merged(group, through.join(" → "), through:)

  def sources = origins.group_by(&:first).map { |name, found| source(name, found.map(&:last)) }

  def origins = of(ABSENT).select { sourced?(it) }.flat_map { |finding| named(finding) }

  def named(finding) = finding.detail[:sources].map { [owner(finding) + it, finding] }

  def source(name, group) = merged(group, name, origin: group.first.detail[:origin])

  def of(kind) = @findings.select { it.kind == kind }

  def owner(finding) = finding.package.sub(OWNER, "")

  def merged(group, package, **told)
    first = group.first
    Hashira::Analysis::Finding.new(
      kind: first.kind, package:, detail: { site: first.detail[:site], places: group.size, **told }.compact,
      evidence: group.map { "#{it.package} (#{it.detail[:site]})" }, anchors: group.flat_map(&:anchors).uniq,
      confidence: first.confidence
    )
  end
end
