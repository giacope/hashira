# frozen_string_literal: true

class Hashira::Report::Confidence
  HIGH = "high"
  MEDIUM = "medium"
  LOW = "low"

  MEASURED = %w[
    cycle sdp_violation mixed_audience wide_edge roll_call complexity layer_violation bidirectional_association
  ].freeze

  NARROW = %i[identical literal message constant].freeze

  HEDGED = %i[structure convention].freeze

  def initialize(finding)
    @finding = finding
  end

  def of
    stated = @finding.confidence
    stated ? stated.to_s : inferred
  end

  private

  def inferred
    kind = @finding.kind
    return copied(@finding.detail.kind) if kind == "duplication"
    MEASURED.include?(kind) ? HIGH : MEDIUM
  end

  def copied(variance)
    return LOW if HEDGED.include?(variance)
    NARROW.include?(variance) ? HIGH : MEDIUM
  end
end
