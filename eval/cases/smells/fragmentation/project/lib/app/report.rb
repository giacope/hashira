module App
  class Report
    def initialize(rows) = @rows = rows

    def render = [title, body].join("\n")

    private

    def title = "#{label}: #{count}"

    def label = name.upcase

    def name = "report"

    def count = @rows.size

    def body = lines.join("\n")

    def lines = @rows.map { line(it) }

    def line(row) = "#{row.name} #{row.total}"
  end

  class Invoice
    def initialize(items, rates)
      @items = items
      @rates = rates
    end

    def total
      subtotal = items_total
      tax = taxes(subtotal)
      subtotal + tax
    end

    private

    def items_total
      @items.sum do |item|
        item.price * item.quantity
      end
    end

    def taxes(amount)
      rate = @rates.fetch(:vat)
      (amount * rate).round(2)
    end
  end

  class Pipeline
    def initialize(db, bus)
      @db = db
      @bus = bus
    end

    def run(input)
      parsed = parse(input)
      checked = check(parsed)
      stored = store(checked)
      notify(stored)
    end

    private

    def parse(input) = JSON.parse(input)

    def check(data) = data.select { it["ok"] }

    def store(rows) = rows.each { @db.insert(it) }

    def notify(rows) = @bus.publish(rows.size)
  end
end
