module App
  class Importer
    def run(rows) = send(:store, rows.map { normalize(it) })

    def report(error) = Hooks.new.fire(self, error)

    private

    def normalize(row) = row.strip

    def store(rows) = rows

    def legacy_format(row) = row.upcase

    def on_error(error) = error
  end

  class Hooks
    def fire(target, kind) = target.public_send("on_#{kind}")
  end

  class Registry
    STALE = 1
    OLD = 2
    private_constant :OLD
  end
end
