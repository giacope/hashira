# frozen_string_literal: true

require "json"

module Hashira
  module CI
    class Baseline
      SCHEMA_VERSION = 2

      def self.load(path) = new(path, File.exist?(path) ? JSON.parse(File.read(path)) : {})

      def initialize(path, recorded)
        @path = path
        @recorded = recorded
      end

      attr_reader :path

      def exist? = File.exist?(@path)

      def edges = @recorded.fetch("edges", [])

      def findings = @recorded.fetch("findings", [])

      def ratchets_findings? = @recorded.key?("findings")

      def write(edges, findings)
        File.write(@path, JSON.pretty_generate(payload(edges, findings)) << "\n")
      end

      private

      def payload(edges, findings)
        base = { version: SCHEMA_VERSION, edges:, findings: }
        accepted = Accepted.new(@recorded.fetch("accepted", [])).entries
        accepted.empty? ? base : base.merge(accepted:)
      end
    end
  end
end
