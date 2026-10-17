module App
  class Exporter
    def export(rows) = rows.map { |row| line(row) }.join("\n")

    def line(row) = raise(NotImplementedError, "#{self.class} must format a row")
  end

  class CsvExporter < Exporter
    def line(row) = row.join(",")
  end

  class Reports
    def csv(rows) = CsvExporter.new.export(rows) + Exporter.new.class.name
  end

  class Error < StandardError
    def initialize(message = "failed") = super
  end

  class TimeoutError < Error
  end

  class Rescuer
    def wrap = yield
  rescue TimeoutError
    raise Error.new("timed out")
  end

  class Document
    def title = "untitled"
  end

  class Draft < Document
    def title = "draft"
  end
end
