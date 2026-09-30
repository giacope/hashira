# frozen_string_literal: true

module Hashira::Report::Confidence
  HIGH = "high"
  MEDIUM = "medium"
  LOW = "low"

  MEASURED = %w[cycle sdp_violation mixed_audience wide_edge roll_call complexity].freeze

  NARROW = %i[identical literal message constant].freeze

  HEDGED = :structure

  module_function

  def of(finding)
    kind = finding.kind
    return copied(finding.detail.kind) if kind == "duplication"
    MEASURED.include?(kind) ? HIGH : MEDIUM
  end

  def copied(variance)
    return LOW if variance == HEDGED
    NARROW.include?(variance) ? HIGH : MEDIUM
  end
end
