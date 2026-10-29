# frozen_string_literal: true

class Evaluation::Outcome
  def self.parse(output)
    [JSON.parse(output)]
  rescue JSON::ParserError
    []
  end

  def initialize(text, status, peak, report)
    @text = text
    @status = status
    @peak = peak
    @report = report
  end

  def to_a = [@text, @status, @peak]

  def probe(path)
    return [:unparsed] if @report.empty?
    path.split(".").reduce(@report) { |found, key| found.flat_map { step(it, key) } }
  end

  def findings = @report.flat_map { it.fetch("findings", []) }

  def kinds(kind) = findings.select { it["kind"] == kind }

  def edges = @report.fetch(0).fetch("edges").to_h { [[it["from"], it["to"]], it["weight"]] }

  private

  def step(value, key)
    return [value.size] if key == "size" && value.respond_to?(:size)
    value.is_a?(Array) ? value.values_at(Integer(key)).compact : [value.fetch(key, nil)].compact
  end
end
