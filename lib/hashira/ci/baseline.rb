# frozen_string_literal: true

require "json"

class Hashira::CI::Baseline
  SCHEMA_VERSION = 3

  def self.load(path) = new(path, File.exist?(path) ? JSON.parse(File.read(path)) : {})

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
