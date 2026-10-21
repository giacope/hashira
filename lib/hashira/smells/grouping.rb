# frozen_string_literal: true

class Hashira::Smells::Grouping
  CHAIN = "message_chain"

  ABSENT = "nil_check"

  REPEATS = "repeated_call"

  OWNER = /[#.][^#.]+\z/

  def initialize(findings)
    @findings = findings
  end

  def findings = @findings.reject { grouped?(it) } + edges + sources + Hashira::Smells::Repeats.new(@findings).findings

  private

  def grouped?(finding) = [CHAIN, REPEATS].include?(finding.kind) || sourced?(finding)

  def sourced?(finding) = finding.kind == ABSENT && finding.detail[:sources].to_a.any?

  def edges
    @findings.select { it.kind == CHAIN }.group_by { it.detail[:through] }.map do |through, group|
      merged(group, through.join(" → "), through:)
    end
  end

  def sources
    @findings.select { sourced?(it) }.flat_map { |finding| named(finding) }.group_by(&:first).map do |name, found|
      merged(found.map(&:last), name, origin: found.first.last.detail[:origin])
    end
  end

  def named(finding) = finding.detail[:sources].map { [finding.package.sub(OWNER, "") + it, finding] }

  def merged(group, package, **told)
    first = group.first
    Hashira::Analysis::Finding.new(
      kind: first.kind, package:, detail: { site: first.detail[:site], places: group.size, **told }.compact,
      evidence: group.map { "#{it.package} (#{it.detail[:site]})" }, anchors: group.flat_map(&:anchors).uniq,
      confidence: first.confidence
    )
  end
end
