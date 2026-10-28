# frozen_string_literal: true

module Shop
  class Report
    def initialize(rows)
      @rows = rows
      @title = "Report"
      @total = rows.sum
      @count = rows.size
      @mean = @total.fdiv(@count)
      @max = rows.max
    end

    def summary = "#{@title}: #{@count} rows, #{@total} total, #{@mean} mean, #{@max} max"
  end
end
