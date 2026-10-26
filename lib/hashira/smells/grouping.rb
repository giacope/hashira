# frozen_string_literal: true

class Hashira::Smells::Grouping
  CHAIN = "message_chain"

  ABSENT = "nil_check"

  REPEATS = "repeated_call"

  OWNER = /[#.][^#.]+\z/

  LOCAL = %w[@ # .].freeze

  GROUPED = [CHAIN, REPEATS, Hashira::Smells::Heirs::KIND, Hashira::Smells::Bequests::KIND].freeze

  def initialize(findings)
    @findings = findings
  end

  def findings
    heirs = Hashira::Smells::Heirs.new(@findings).findings + Hashira::Smells::Bequests.new(@findings).findings
    @findings.reject { grouped?(it) } + edges + sources + heirs + Hashira::Smells::Repeats.new(@findings).findings
  end

  private

  def grouped?(finding) = GROUPED.include?(finding.kind) || sourced?(finding)

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

  def named(finding)
    owner = finding.package.sub(OWNER, "")
    finding.detail[:sources].map { [it.start_with?(*LOCAL) ? owner + it : it, finding] }
  end

  def merged(group, package, **told)
    first = group.first
    Hashira::Analysis::Finding.new(
      kind: first.kind, package:, detail: { site: first.detail[:site], places: group.size, **told }.compact,
      evidence: group.map { "#{it.package} (#{it.detail[:site]})" }, anchors: group.flat_map(&:anchors).uniq,
      confidence: first.confidence
    )
  end
end
