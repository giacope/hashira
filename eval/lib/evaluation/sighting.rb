# frozen_string_literal: true

class Evaluation::Sighting
  SITE = /\A(?<path>.+?):(?<first>\d+)(?:[-,]\s*(?<last>\d+))?/

  def initialize(corpus, finding, home)
    @corpus = corpus
    @finding = finding
    @home = home
  end

  def kind = @finding.fetch("kind")

  def key = "#{@corpus}|#{kind}|#{identity}"

  def entry
    { "key" => key, "message" => @finding["message"], "evidence" => @finding["evidence"] }.merge("code" => code)
  end

  private

  def identity = kind == "duplication" ? starts.join(",") : @finding["digest"] || @finding["package"]

  def starts = @finding["evidence"].map { it.sub(/-\d+\z/, "") }.sort

  def sites
    case kind
    when "duplication" then @finding.fetch("evidence")
    when "change_coupling" then @finding.dig("detail", "files").map { "#{it}:1" }
    else [@finding.dig("detail", "site") || @finding["package"]]
    end
  end

  def code = sites.flat_map { excerpt(SITE.match(it.to_s)) }

  def excerpt(site)
    return [] unless site
    path, first, last = site.captures
    file = File.join(@home, path)
    return [] unless File.file?(file)
    lines = File.readlines(file)
    ["# #{site}", *span(first, last).filter_map { "#{it}: #{lines[it - 1].chomp}" if lines[it - 1] }]
  end

  def span(first, last)
    start = Integer(first)
    start..(last ? [Integer(last), start + 40].min : start + 24)
  end
end
