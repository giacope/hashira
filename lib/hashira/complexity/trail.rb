# frozen_string_literal: true

class Hashira::Complexity::Trail
  Trace = Data.define(:site, :cognitive, :own, :helpers, :depth)

  def initialize(file, site, helpers)
    @file = file
    @site = site
    @helpers = helpers
  end

  def finding(limit) = (build if hidden?(limit))

  private

  def hidden?(limit) = score.inlined.any? && score.total >= limit && own < limit

  def score = @_score ||= Hashira::Complexity::InlinedScore.new(@site.node, @helpers)

  def own = @_own ||= Hashira::Complexity::CognitiveScore.new(@site.node).total

  def spot = "#{@file}:#{@site.node.location.start_line}"

  def build
    Hashira::Analysis::Finding.new(
      kind: Hashira::Complexity::Indirection::KIND, package: @site.subject, detail: trace, evidence:, anchors: [spot]
    )
  end

  def trace = Trace.new(site: spot, cognitive: score.total, own:, helpers: score.inlined.size, depth: score.depth)

  def evidence = score.inlined.map { "#{it.name} (line #{it.location.start_line})" }
end
