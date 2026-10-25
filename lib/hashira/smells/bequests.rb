# frozen_string_literal: true

class Hashira::Smells::Bequests
  KIND = "refused_bequest"

  OWNER = /[#.][^#.]+\z/

  def initialize(findings)
    @findings = findings
  end

  def findings
    refusals = @findings.select { it.kind == KIND }.flat_map { |found| found.detail[:refusals].map { [found, it] } }
    refusals.group_by { |_finding, refused| refused.bequest }.map { merged(*it) }
  end

  private

  def merged(method, group)
    first, refused = group.first
    home = refused.home
    Hashira::Analysis::Finding.new(
      kind: KIND, package: method, detail: { site: home, places: group.size, parent: method.sub(OWNER, "") },
      evidence: group.map { |finding, refusal| "#{finding.package} #{refusal.verb} (#{refusal.site})" },
      anchors: [home, *group.flat_map { |finding, _refusal| finding.anchors }].uniq, confidence: first.confidence
    )
  end
end
