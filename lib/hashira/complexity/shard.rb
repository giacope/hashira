# frozen_string_literal: true

class Hashira::Complexity::Shard
  class Spread
    HIDDEN_OBJECT = 15

    MERGE = "Merge the helpers that only move data into the entry; keep named predicates."

    EXTRACT = "That many private steps are an object hiding inside the class: extract it and give it a name."

    private_constant :HIDDEN_OBJECT, :MERGE, :EXTRACT

    def initialize(site:, helpers:, lines:, path:)
      @site = site
      @helpers = helpers
      @lines = lines
      @path = path
    end

    def to_h = { site: @site, helpers: @helpers, lines: @lines, depth: @path.size - 1, path: @path }

    def phrase(package)
      "#{package} spreads its work over #{Hashira::Prose::Count.new(@helpers, "private helper")} only it calls, " \
        "averaging #{format("%.1f", @lines)} lines a method, #{@path.size - 1} deep (#{@path.join(" → ")}) " \
        "(#{@site}). #{@helpers > HIDDEN_OBJECT ? EXTRACT : MERGE}"
    end
  end

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

  def predicate?(helper) = helper.name.end_with?(QUESTION)

  def mean = @_mean ||= methods.sum { Hashira::Complexity::Span.new(it, @notes).size }.fdiv(methods.size)

  def methods = @reach.methods

  def build = @entry.finding(spread, found.map { [it, (UNCOUNTED if predicate?(it))] })

  def spread
    Spread.new(site: @entry.spot, helpers: counted.size, lines: mean.round(2), path: @reach.path)
  end
end
