# frozen_string_literal: true

class Hashira::Analysis::Confidence
  HIGH = "high"

  MEDIUM = "medium"

  LOW = "low"

  CLONES = "duplication"

  MEASURED = %w[
    cycle unstable_dependency mixed_audience wide_edge roll_call complexity layer_violation bidirectional_association
  ].freeze

  NARROW = %i[identical literal message constant].freeze

  HEDGED = %i[structure convention].freeze

  def initialize(kind, detail)
    @kind = kind
    @detail = detail
  end

  def to_s
    return copied(@detail.to_h.fetch(:kind)) if @kind == CLONES
    MEASURED.include?(@kind) ? HIGH : MEDIUM
  end

  private

  def copied(variance)
    return LOW if HEDGED.include?(variance)
    NARROW.include?(variance) ? HIGH : MEDIUM
  end
end
