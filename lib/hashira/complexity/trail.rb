# frozen_string_literal: true

class Hashira::Complexity::Trail
  Trace = Data.define(:site, :chain)

  def initialize(file, site, helpers)
    @file = file
    @site = site
    @helpers = helpers
  end

  def finding(limit) = (build if path.size >= limit)

  private

  def path = @_path ||= Hashira::Complexity::Hops.new(@helpers).longest(@site.node)

  def line(node) = node.location.start_line

  def spot = "#{@file}:#{@site.node.location.start_line}"

  def build
    Hashira::Analysis::Finding.new(
      kind: Hashira::Complexity::Indirection::KIND, package: @site.subject, anchors: [spot],
      detail: Trace.new(site: spot, chain: path.size), evidence: path.map { "#{it.name} (line #{line(it)})" }
    )
  end
end
