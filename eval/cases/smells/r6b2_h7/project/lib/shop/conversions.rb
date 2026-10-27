# frozen_string_literal: true

module Shop
  class Report
    def to_csv = summary.tr(" ", ",")
  end
end
