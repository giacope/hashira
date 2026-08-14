# frozen_string_literal: true

require "json"

class Hashira::CI::Accepted
  Screened = Data.define(:all, :accepted)

  Entry =
    Data.define(:kind, :package, :digest, :reason) do
      def self.build(hash)
        new(kind: hash["kind"], package: hash["package"], digest: hash["digest"], reason: hash["reason"])
      end

      def matches?(finding) = kind == finding.kind && identity == finding.identity

      def identity = digest || package

      def label = reason || "accepted (no reason recorded)"

      def to_h = super.compact
    end

  def self.build(path) = new(Hashira::CI::Baseline.new(path).accepted)

  def initialize(list)
    @list = list
  end

  def entries = records.map(&:to_h)

  def screen(findings)
    accepted, live = findings.map { [it, reason(it)] }.partition(&:last)
    Screened.new(all: live.map(&:first), accepted:)
  end

  private

  def records = @_records ||= @list.map { Entry.build(it) }

  def reason(finding)
    records.find { it.matches?(finding) }&.label
  end
end
