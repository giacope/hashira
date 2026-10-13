# frozen_string_literal: true

class Hashira::Complexity::Shard
  Spread = Data.define(:site, :helpers, :lines, :depth, :path)

  DEPTH = 2

  def initialize(entry, reach, notes)
    @entry = entry
    @reach = reach
    @notes = notes
  end

  def finding(helpers, lines) = (build if spread?(helpers) && mean <= lines)

  private

  def spread?(helpers) = found.size >= helpers && @reach.depth >= DEPTH

  def found = @reach.helpers

  def mean = @_mean ||= methods.sum { Hashira::Complexity::Span.new(it.node, @notes).size }.fdiv(methods.size)

  def methods = [@entry.site] + found

  def build = @entry.finding(spread, found.map(&:node))

  def spread
    Spread.new(site: @entry.spot, helpers: found.size, lines: mean.round(2), depth: @reach.depth, path: @reach.path)
  end
end
