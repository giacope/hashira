module Shop
  class Exporter
    def initialize(io)
      @io = io
    end

    def export(report)
      @io.puts([report.title, report.rows.size, report.footer].join(","))
    end
  end
end
