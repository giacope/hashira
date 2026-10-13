# frozen_string_literal: true

class Hashira::Complexity::Trail
  Trace = Data.define(:site, :chain)

  def initialize(entry, helpers)
    @entry = entry
    @helpers = helpers
  end

  def finding(limit) = (build if path.size >= limit)

  private

  def path = @_path ||= Hashira::Complexity::Hops.new(@helpers).longest(@entry.site.node)

  def build = @entry.finding(Trace.new(site: @entry.spot, chain: path.size), path)
end
