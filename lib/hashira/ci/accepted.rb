# frozen_string_literal: true

require "json"

class Hashira::CI::Accepted
  Screened = Data.define(:all, :accepted)

  Entry =
    Data.define(:kind, :package, :digest, :reason) do
      def self.from(hash)
        new(kind: hash["kind"], package: hash["package"], digest: hash["digest"], reason: hash["reason"])
      end

      def matches?(finding) = kind == finding.kind && identity == finding.identity

      def identity = digest || package

      def label = reason || "accepted (no reason recorded)"

      def to_h = { kind:, package:, digest:, reason: }.compact
    end

  def self.load(path)
    return new([]) unless path && File.exist?(path)
    new(JSON.parse(File.read(path)).fetch("accepted", []))
  end

  def initialize(entries)
    @entries = entries.map { Entry.from(it) }
  end

  def entries = @entries.map(&:to_h)

  def screen(findings)
    accepted, live = findings.map { [it, reason(it)] }.partition(&:last)
    Screened.new(all: live.map(&:first), accepted:)
  end

  private

  def reason(finding)
    @entries.find { it.matches?(finding) }&.label
  end
end
