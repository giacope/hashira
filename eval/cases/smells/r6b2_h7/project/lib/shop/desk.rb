# frozen_string_literal: true

module Shop
  class Desk
    def daily(rows) = Report.new(rows).summary
  end
end
