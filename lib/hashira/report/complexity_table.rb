# frozen_string_literal: true

class Hashira::Report::ComplexityTable
  TOP = 10
  METHOD_HEADERS = %w[method Cog Calls Loc].freeze
  CLASS_HEADERS = %w[class Cog Methods Peak].freeze
  METHOD_TITLE = "Cognitive complexity — worst methods (Cog = how hard to read, Calls = message sends)"
  CLASS_TITLE = "Per-class rollup (Cog total survives extract-method; Peak is the worst method it hides)"

  def initialize(complexity, top: TOP, io: $stdout)
    @complexity = complexity
    @top = top
    @io = io
  end

  def print
    section(@complexity.ranked, METHOD_HEADERS, METHOD_TITLE)
    section(@complexity.classes, CLASS_HEADERS, CLASS_TITLE)
  end

  private

  def section(scores, headers, title)
    rows = ranked(scores)
    return if rows.empty?
    @io.puts("#{title}:\n\n")
    Hashira::Report::Columns.new(headers, rows.map(&:cells), io: @io).print
    @io.puts
  end

  def ranked(scores) = scores.select { it.cognitive.positive? }.first(@top)
end
