# frozen_string_literal: true

class Hashira::Suppression::Silence
  def initialize(finding, directives)
    @finding = finding
    @directives = directives
  end

  def verdict
    return [@finding, [], []] if matched.empty?
    return [trimmed, [], matched.map(&:last)] if partial?
    [nil, [[@finding, matched.first.last]], matched.map(&:last)]
  end

  private

  def kind = @finding.kind

  def matched
    @_matched ||= @finding.anchors.filter_map { |anchor| [anchor, @directives.find { it.covers?(kind, anchor) }] }
      .select(&:last)
  end

  def silenced = matched.map(&:first)

  def partial? = kind == Hashira::Analysis::CLONES && rest.size >= 2

  def rest = @finding.evidence.reject { silenced.include?(it.sub(/-\d+\z/, "")) }

  def trimmed
    starts = rest.map { it.sub(/-\d+\z/, "") }
    @finding.with(package: starts.first, evidence: rest, detail: @finding.detail.with(size: rest.size), anchors: starts)
  end
end
