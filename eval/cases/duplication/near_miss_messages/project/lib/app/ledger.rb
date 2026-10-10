module App
  class Ledger
    def balances(accounts, closed)
      totals = accounts.map { |account| account.balance }
      totals -= closed.map { |account| account.balance } if closed.any?
      @audit.record("totals #{totals.sum} for #{accounts.count}")
      totals
    end
  end
end
