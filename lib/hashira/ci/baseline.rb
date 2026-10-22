# frozen_string_literal: true

require "json"

class Hashira::CI::Baseline
  SCHEMA_VERSION = 7
  ENCODING = Encoding::UTF_8

  RENAMES = {
    "duplicate_method_call" => "repeated_call", "too_many_instance_variables" => "state_sprawl",
    "instance_variable_assumption" => "assumed_state", "sdp_violation" => "unstable_dependency"
  }.freeze

  INTRODUCED = { "indirection" => 7, "fragmentation" => 7 }.freeze

  def initialize(path, analyzers: [], targets: [], kinds: [])
    @path = path
    @analyzers = analyzers
    @targets = targets
    @kinds = kinds
  end

  attr_reader :path

  def exist? = File.exist?(@path)

  def trouble
    recorded && nil
  rescue JSON::ParserError, SystemCallError => error
    "#{@path} is not a usable baseline — #{error.message.lines.first.strip}. Re-record it with --update-baseline"
  end

  def edges = recorded.fetch("edges", [])

  def marks = recorded.fetch("findings", {}).to_h { |key, magnitude| [renamed(key), mark(key, magnitude)] }

  def predates?(kind) = recorded.key?("kinds") ? !recorded["kinds"].include?(kind) : INTRODUCED.fetch(kind, 0) > version

  def version = recorded.fetch("version", SCHEMA_VERSION)

  def traces = recorded.fetch("traces", {})

  def findings? = recorded.key?("findings")

  def accepted = recorded.fetch("accepted", []).map { it.merge("kind" => current(it["kind"])) }

  def boundaries = recorded.fetch("boundaries", [])

  def packaging = recorded.fetch("packaging", "folder")

  def analyzers = recorded.fetch("analyzers", wanted[:analyzers])

  def targets = recorded.fetch("targets", wanted[:targets])

  def wanted = scope.to_h

  def write(edges, marks, packaging:)
    File.write(@path, JSON.pretty_generate(payload(edges, marks, packaging)) << "\n", encoding: ENCODING)
  end

  private

  def recorded
    @_recorded ||= read
  end

  def read
    return {} unless @path && File.exist?(@path)
    stored = JSON.parse(File.read(@path, encoding: ENCODING))
    stored.is_a?(Hash) ? stored : raise(JSON::ParserError, "its top level is a list, not an object")
  end

  def renamed(key)
    kind, identity = key.split(":", 2)
    "#{current(kind)}:#{identity}"
  end

  def current(kind) = RENAMES.fetch(kind, kind)

  def mark(key, magnitude) = Hashira::CI::Mark.new(magnitude:, trace: traces[key])

  def scope = Hashira::CI::Scope.new(analyzers: @analyzers, targets: @targets)

  def payload(edges, marks, packaging)
    stem(packaging).merge(edges:, findings: sized(marks)).merge(traced(marks)).merge(kept)
  end

  def stem(packaging) = { version: SCHEMA_VERSION, packaging: }.merge(scope.to_h).merge(optional(:kinds, @kinds.sort))

  def sized(marks) = marks.transform_values(&:magnitude)

  def traced(marks)
    found = marks.transform_values(&:trace).compact
    found.empty? ? {} : { traces: found }
  end

  def kept
    optional(:accepted, Hashira::CI::Accepted.new(accepted).entries).merge(optional(:boundaries, boundaries))
  end

  def optional(name, values) = values.empty? ? {} : { name => values }
end
