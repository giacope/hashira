module App
  class Import
    def run(rows, target)
      valid = rows.reject { |row| row.fetch(:id).nil? }
      grouped = valid.group_by { |row| row.fetch(:account) }
      grouped.each { |account, list| target.store(account, list.sum { |row| row.fetch(:amount) }) }
      target.flush
    end
  end
end
