module App
  module Drift
    def hits = exact.empty? ? drifted : exact

    def exact = matching(anchors)

    def drifted = matching(anchors.except(:line))
  end

  class LedgerEntry
    include Drift

    def initialize(fields, rows)
      @fields = fields
      @rows = rows
    end

    def kind = hits.empty? ? :stale : :live
    def moved = exact.empty? ? hits.first : nil
    def kept = moved ? @fields.merge(line: moved) : @fields
    def place = "#{@fields[:file]}:#{moved}"
    def anchors = @fields.except(:file)
    def matching(anchors) = @rows.select { |row| anchors <= row }
    def statuses = @rows.map { it[:status] }
  end
end
