# frozen_string_literal: true

class Hashira::Report::FindingList
  TOP = 25

  def initialize(findings, top: TOP, io: $stdout)
    @findings = findings
    @top = top
    @io = io
  end

  def print
    return listed if rest.zero?
    tally
    listed
    @io.puts(Hashira::Report::Phrases.withheld(rest))
  end

  private

  def shown = @_shown ||= Hashira::Report::Spread.new(@findings).to_a.first(@top)

  def rest = @findings.size - shown.size

  def rows = @_rows ||= Hashira::Report::Tally.new(@findings).rows

  def listed = shown.each { Hashira::Report::FindingLines.new(it, indent: "  ", io: @io).emit }

  def tally
    rows.each { @io.puts(it.line(wide, tall)) }
    @io.puts
  end

  def wide = rows.map { it.kind.length }.max

  def tall = rows.first.count.to_s.length
end
