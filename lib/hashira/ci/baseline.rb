# frozen_string_literal: true

require "json"

class Hashira::CI::Baseline
  SCHEMA_VERSION = 4

  def self.load(path, analyzers: [], targets: [])
    new(path, read(path), Hashira::CI::Scope.new(analyzers:, targets:))
  end

  def self.read(path)
    return {} unless path && File.exist?(path)
    recorded = JSON.parse(File.read(path))
    recorded.is_a?(Hash) ? recorded : raise(JSON::ParserError, "its top level is a list, not an object")
  end

  def self.trouble(path)
    read(path) && nil
  rescue JSON::ParserError, SystemCallError => error
    "#{path} is not a usable baseline — #{error.message.lines.first.strip}. Re-record it with --update-baseline"
  end

  def initialize(path, recorded, scope = Hashira::CI::Scope.none)
    @path = path
    @recorded = recorded
    @scope = scope
  end

  attr_reader :path

  def exist? = File.exist?(@path)

  def edges = @recorded.fetch("edges", [])

  def findings = self.class.scored(@recorded.fetch("findings", {}))

  def self.scored(recorded) = recorded.is_a?(Array) ? recorded.to_h { [it, nil] } : recorded

  def findings? = @recorded.key?("findings")

  def packaging = @recorded.fetch("packaging", "folder")

  def analyzers = @recorded.fetch("analyzers", wanted[:analyzers])

  def targets = @recorded.fetch("targets", wanted[:targets])

  def wanted = @scope.to_h

  def write(edges, findings, packaging:)
    File.write(@path, JSON.pretty_generate(payload(edges, findings, packaging)) << "\n")
  end

  private

  def payload(edges, findings, packaging)
    base = { version: SCHEMA_VERSION, packaging:, **@scope.to_h, edges:, findings: }
    accepted = Hashira::CI::Accepted.new(@recorded.fetch("accepted", [])).entries
    accepted.empty? ? base : base.merge(accepted:)
  end
end
