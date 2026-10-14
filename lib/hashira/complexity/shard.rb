# frozen_string_literal: true

class Hashira::Complexity::Shard
  Spread = Data.define(:site, :helpers, :lines, :depth, :path)

  DEPTH = 2

  QUESTION = "?"

  UNCOUNTED = " (predicate, not counted)"

  def initialize(entry, reach, notes)
    @entry = entry
    @reach = reach
    @notes = notes
  end

  def finding(helpers, lines) = (build if spread?(helpers) && mean <= lines)

  private

  def spread?(helpers) = counted.size >= helpers && @reach.depth >= DEPTH

  def found = @reach.helpers

  def counted = @_counted ||= found.reject { predicate?(it) }

  def predicate?(helper) = helper.node.name.end_with?(QUESTION)

  def mean = @_mean ||= methods.sum { Hashira::Complexity::Span.new(it.node, @notes).size }.fdiv(methods.size)

  def methods = [@entry.site] + found

  def build = @entry.finding(spread, found.map { cited(it) })

  def cited(helper) = "#{@entry.cite(helper.node)}#{UNCOUNTED if predicate?(helper)}"

  def spread
    Spread.new(site: @entry.spot, helpers: counted.size, lines: mean.round(2), depth: @reach.depth, path: @reach.path)
  end
end
