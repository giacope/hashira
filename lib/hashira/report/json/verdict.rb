# frozen_string_literal: true

class Hashira::Report::Json::Verdict
  def initialize(findings, screened)
    @findings = findings
    @screened = screened
  end

  def to_h(cap)
    _, silenced, unused = @screened.to_a
    {
      findings: cap.call(spread).map(&:to_h), kinds: Hashira::Report::Tally.new(@findings.to_a).to_h, accepted:,
      suppressed: silenced.map { |finding, note| finding.to_h.merge(cited(note)) },
      unused_suppressions: unused.map(&:to_h)
    }
  end

  def lists = { findings: spread }

  private

  def spread = @_spread ||= Hashira::Report::Spread.new(@findings.to_a).to_a

  def accepted = @findings.to_h.map { |finding, reason| finding.to_h.merge(reason:) }

  def cited(note) = note.to_h.slice("site", "reason").transform_keys(&:to_sym)
end
