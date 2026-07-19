# frozen_string_literal: true

require "json"

module Hashira
  module CI
    class Accepted
      Screened = Data.define(:all, :accepted)

      Entry = Data.define(:kind, :package, :reason) do
        def self.from(hash) = new(kind: hash["kind"], package: hash["package"], reason: hash["reason"])

        def matches?(finding) = [kind, package] == [finding.kind, finding.package]

        def label = reason || "accepted (no reason recorded)"

        def to_h = { kind:, package:, reason: }.compact
      end

      def self.load(path)
        return new([]) unless path && File.exist?(path)

        new(JSON.parse(File.read(path)).fetch("accepted", []))
      end

      def initialize(entries)
        @entries = entries.map { Entry.from(_1) }
      end

      def entries = @entries.map(&:to_h)

      def screen(findings)
        accepted, live = findings.map { [_1, reason_for(_1)] }.partition(&:last)
        Screened.new(all: live.map(&:first), accepted:)
      end

      private

      def reason_for(finding)
        @entries.find { _1.matches?(finding) }&.label
      end
    end
  end
end
