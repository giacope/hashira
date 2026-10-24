# frozen_string_literal: true

class Hashira::Smells::Heirs
  KIND = "concrete_inheritance"

  def initialize(findings)
    @findings = findings
  end

  def findings = @findings.select { it.kind == KIND }.group_by { it.detail[:parent] }.map { merged(*it) }

  private

  def merged(parent, group)
    first = group.first
    home = first.detail[:home]
    Hashira::Analysis::Finding.new(
      kind: KIND, package: parent, detail: { site: home, places: group.size, parent: },
      evidence: group.map { "#{it.package} (#{it.detail[:site]})" } + first.evidence,
      anchors: [home, *group.flat_map(&:anchors)].uniq, confidence: first.confidence
    )
  end
end
