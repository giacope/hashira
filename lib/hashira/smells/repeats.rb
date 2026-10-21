# frozen_string_literal: true

class Hashira::Smells::Repeats
  KIND = "repeated_call"

  OWNER = /[#.][^#.]+\z/

  def initialize(findings)
    @findings = findings
  end

  def findings
    @findings.select { it.kind == KIND }.group_by { it.package.sub(OWNER, "") }.map { merged(*it) }
  end

  private

  def merged(owner, group)
    Hashira::Analysis::Finding.new(
      kind: KIND, package: owner, evidence: group.flat_map { told(it, owner) }, anchors: group.flat_map(&:anchors).uniq,
      detail: { site: group.first.detail[:site], places: group.size, calls: group.sum { it.evidence.size } },
      confidence: (:low if group.all?(&:doubted?))
    )
  end

  def told(finding, owner) = finding.evidence.map { "#{finding.package.delete_prefix(owner)}: #{it}" }
end
