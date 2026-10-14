# frozen_string_literal: true

module Evaluation
  Peak =
    Data.define(:seconds, :kilobytes) do
      def self.of(path)
        seconds, kilobytes = File.exist?(path) ? File.read(path).split : [0, 0]
        new(seconds: Float(seconds), kilobytes: Integer(kilobytes))
      end

      def megabytes = (kilobytes / 1024.0).round(1)
    end

  Outcome =
    Data.define(:status, :output, :error, :peak, :json) do
      def self.parse(output)
        JSON.parse(output)
      rescue JSON::ParserError
        nil
      end

      def text = "#{output}#{error}"

      def findings = json ? json.fetch("findings", []) : []

      def kinds(kind) = findings.select { it["kind"] == kind }

      def edges = json.fetch("edges").to_h { [[it["from"], it["to"]], it["weight"]] }
    end
end
