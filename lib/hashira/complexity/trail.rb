# frozen_string_literal: true

class Hashira::Complexity::Trail
  class Trace
    def initialize(site:, chain:)
      @site = site
      @chain = chain
    end

    def to_h = { site: @site, chain: @chain }

    def phrase(package)
      "#{package} reaches its work through #{Hashira::Prose::Count.new(@chain, "hollow helper")}, " \
        "private one-liners called once that only pass a call on (#{@site}). Inline them into their callers."
    end
  end

  def initialize(entry, helpers)
    @entry = entry
    @helpers = helpers
  end

  def finding(limit) = (build if path.size >= limit)

  private

  def path = @_path ||= Hashira::Complexity::Hops.new(@helpers).longest(@entry.site.node)

  def build = @entry.finding(Trace.new(site: @entry.spot, chain: path.size), path.map { @entry.cite(it) })
end
