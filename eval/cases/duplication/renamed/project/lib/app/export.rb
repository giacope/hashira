module App
  class Export
    def run(records, sink)
      kept = records.reject { |record| record.fetch(:id).nil? }
      buckets = kept.group_by { |record| record.fetch(:account) }
      buckets.each { |account, items| sink.store(account, items.sum { |record| record.fetch(:amount) }) }
      sink.close
      sink.flush
    end
  end
end
