class Invoice < ApplicationRecord
  def label = "Invoice #{id}: #{TaxTable.new.rate}"

  private

  def stale_total = 0
end
