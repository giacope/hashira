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

  UNUSABLE = "%s is not a usable baseline — %s. Re-record it with --update-baseline"

  PACKAGING = "baseline %s was recorded with --package-by %s, but this run uses %s — rerun with --package-by %s, " \
    "or refresh it with --update-baseline"

  def initialize(path, analyzers: [], targets: [], kinds: [])
    @path = path
    @analyzers = analyzers
    @targets = targets
    @kinds = kinds
  end

  def to_s = @path.to_s

  def accepted
    entries = recorded.fetch("accepted", []).map { it.merge("kind" => current(it["kind"])) }
    Hashira::CI::Accepted.new(entries, recorded.fetch("boundaries", []))
  end

  def history
    newer = @kinds.select { predates?(it) }
    Hashira::CI::History.new(recorded.fetch("edges", []), recorded.key?("findings") ? [marks] : [], newer)
  end

  def vet(packaging)
    raise(Hashira::Error, "no baseline at #{@path} — run --update-baseline first") unless File.exist?(@path)
    stop = [*mismatch(packaging), *scope.widened(recorded, self)].first
    raise(Hashira::Error, stop) if stop
  end

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
  rescue JSON::ParserError, SystemCallError => error
    raise(Hashira::Error, format(UNUSABLE, @path, error.message.lines.first.strip))
  end

  def marks
    traces = recorded.fetch("traces", {})
    named = recorded.fetch("findings", {}).to_h { |key, size| [renamed(key), [size, traces.fetch(key, nil)]] }
    Hashira::CI::Marks.new(named.transform_values(&:first), named.transform_values(&:last).compact)
  end

  def renamed(key)
    kind, identity = key.split(":", 2)
    "#{current(kind)}:#{identity}"
  end

  def current(kind) = RENAMES.fetch(kind, kind)

  def predates?(kind) = recorded.key?("kinds") ? !recorded["kinds"].include?(kind) : INTRODUCED.fetch(kind, 0) > version

  def version = recorded.fetch("version", SCHEMA_VERSION)

  def mismatch(packaging)
    was = recorded.fetch("packaging", "folder")
    was == packaging ? [] : [format(PACKAGING, @path, was, packaging, was)]
  end

  def scope = Hashira::CI::Scope.new(analyzers: @analyzers, targets: @targets)

  def payload(edges, marks, packaging)
    stem = { version: SCHEMA_VERSION, packaging: }.merge(scope.to_h).merge(optional(:kinds, @kinds.sort))
    stem.merge(edges:).merge(marks.to_h).merge(accepted.to_h)
  end

  def optional(name, values) = values.empty? ? {} : { name => values }
end
