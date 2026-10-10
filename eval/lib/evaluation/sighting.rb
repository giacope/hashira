# frozen_string_literal: true

module Evaluation
  SITE = /\A(?<path>.+?):(?<first>\d+)(?:[-,]\s*(?<last>\d+))?/

  Sighting =
    Data.define(:corpus, :finding, :home) do
      def kind = finding["kind"]

      def key = "#{corpus}|#{kind}|#{identity}"

      def identity = kind == "duplication" ? starts.join(",") : finding["package"]

      def starts = finding["evidence"].map { it.sub(/-\d+\z/, "") }.sort

      def rank = Digest::SHA256.hexdigest(key)

      def sites = kind == "duplication" ? finding["evidence"] : [finding.dig("detail", "site") || finding["package"]]

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
