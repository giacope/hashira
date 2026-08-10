# frozen_string_literal: true

require "json"

class Hashira::CI::Baseline
  SCHEMA_VERSION = 3

  def self.load(path) = new(path, read(path))

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

  def initialize(path, recorded)
    @path = path
    @recorded = recorded
  end

  attr_reader :path

  def exist? = File.exist?(@path)

  def edges = @recorded.fetch("edges", [])

  def findings = @recorded.fetch("findings", [])

  def findings? = @recorded.key?("findings")

  def packaging = @recorded.fetch("packaging", "folder")

  def write(edges, findings, packaging:)
    File.write(@path, JSON.pretty_generate(payload(edges, findings, packaging)) << "\n")
  end

  private

  def payload(edges, findings, packaging)
    base = { version: SCHEMA_VERSION, packaging:, edges:, findings: }
    accepted = Hashira::CI::Accepted.new(@recorded.fetch("accepted", [])).entries
    accepted.empty? ? base : base.merge(accepted:)
  end
end
