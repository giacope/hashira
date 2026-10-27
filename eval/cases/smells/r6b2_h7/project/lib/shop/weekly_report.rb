# frozen_string_literal: true

module Shop
  class WeeklyReport < Report
    def summary = "Week: #{super}"
  end
end
