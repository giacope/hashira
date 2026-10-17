# frozen_string_literal: true

module Evaluation
  SITE = /\A(?<path>.+?):(?<first>\d+)(?:[-,]\s*(?<last>\d+))?/

  Sighting =
    Data.define(:corpus, :finding, :home) do
      def kind = finding["kind"]

      def key = "#{corpus}|#{kind}|#{identity}"

      def identity = kind == "duplication" ? starts.join(",") : finding["digest"] || finding["package"]

      def starts = finding["evidence"].map { it.sub(/-\d+\z/, "") }.sort

      def sites
        case kind
        when "duplication" then finding["evidence"]
        when "change_coupling" then finding.dig("detail", "files").map { "#{it}:1" }
        else [finding.dig("detail", "site") || finding["package"]]
        end
      end

      def entry
        { "key" => key, "message" => finding["message"], "evidence" => finding["evidence"] }.merge("code" => code)
      end

      def code = sites.flat_map { excerpt(SITE.match(it.to_s)) }

      def excerpt(site)
        path = site && File.join(home, site[:path])
        return [] unless path && File.file?(path)
        lines = File.readlines(path)
        ["# #{site}", *span(site).filter_map { "#{it}: #{lines[it - 1].chomp}" if lines[it - 1] }]
      end

      def span(site)
        start = Integer(site[:first])
        start..(site[:last] ? [Integer(site[:last]), start + 40].min : start + 24)
      end
    end
end
