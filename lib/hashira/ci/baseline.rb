# frozen_string_literal: true

require "json"

class Hashira::CI::Baseline
  SCHEMA_VERSION = 5

  def initialize(path, analyzers: [], targets: [])
    @path = path
    @analyzers = analyzers
    @targets = targets
  end

  attr_reader :path

  def exist? = File.exist?(@path)

  def trouble
    recorded && nil
  rescue JSON::ParserError, SystemCallError => error
    "#{@path} is not a usable baseline — #{error.message.lines.first.strip}. Re-record it with --update-baseline"
  end

  def edges = recorded.fetch("edges", [])

  def findings = keyed(recorded.fetch("findings", {}))

  def marks = findings.to_h { |key, magnitude| [key, Hashira::CI::Mark.new(magnitude:, trace: traces[key])] }

  def traces = recorded.fetch("traces", {})

  def findings? = recorded.key?("findings")

  def accepted = recorded.fetch("accepted", [])

  def packaging = recorded.fetch("packaging", "folder")

  def analyzers = recorded.fetch("analyzers", wanted[:analyzers])

  def targets = recorded.fetch("targets", wanted[:targets])

  def wanted = scope.to_h

  def write(edges, marks, packaging:)
    File.write(@path, JSON.pretty_generate(payload(edges, marks, packaging)) << "\n")
  end

  private

  def recorded
    @_recorded ||= read
  end

  def read
    return {} unless @path && File.exist?(@path)
    stored = JSON.parse(File.read(@path))
    stored.is_a?(Hash) ? stored : raise(JSON::ParserError, "its top level is a list, not an object")
  end

  def keyed(findings) = findings.is_a?(Array) ? findings.to_h { [it, nil] } : findings

  def scope = Hashira::CI::Scope.new(analyzers: @analyzers, targets: @targets)

  def payload(edges, marks, packaging)
    stem(packaging).merge(edges:, findings: sized(marks)).merge(traced(marks)).merge(kept)
  end

  def stem(packaging) = { version: SCHEMA_VERSION, packaging: }.merge(scope.to_h)

  def sized(marks) = marks.transform_values(&:magnitude)

  def traced(marks)
    found = marks.transform_values(&:trace).compact
    found.empty? ? {} : { traces: found }
  end

  def kept
    entries = Hashira::CI::Accepted.new(accepted).entries
    entries.empty? ? {} : { accepted: entries }
  end
end
