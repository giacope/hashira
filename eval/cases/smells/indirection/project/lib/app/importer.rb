module App
  class Importer
    def initialize(store) = @store = store

    def run(rows)
      parsed = parse(rows)
      save(parsed)
    end

    private

    def parse(rows)
      rows.filter_map do |row|
        clean(row) if row && !row.empty?
      end
    end

    def clean(row)
      if row.key?(:id)
        row.transform_values { |value| value.is_a?(String) ? value.strip : value }
      elsif row.key?(:ref)
        { id: row[:ref] }
      end
    end

    def save(rows)
      rows.each do |row|
        if row[:id]
          @store.put(row)
        else
          @store.skip(row)
        end
      end
    rescue IOError
      @store.rollback
    end
  end

  class Pricing
    def initialize(rates) = @rates = rates

    def quote(item) = round(taxed(item))

    def invoice(items) = items.sum { round(taxed(it)) }

    private

    def taxed(item)
      if item.exempt?
        item.price
      elsif item.reduced?
        item.price * @rates.reduced
      else
        item.price * @rates.full
      end
    end

    def round(amount) = amount.positive? ? amount.round(2) : 0
  end
end
