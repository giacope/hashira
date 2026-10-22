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
    @io.puts(Hashira::Report::Withheld.new(rest).to_s)
  end

  private

  def shown = @_shown ||= Hashira::Report::Spread.new(@findings).to_a.first(@top)

  def rest = @findings.size - shown.size

  def listed = shown.each { Hashira::Report::FindingLines.new(it, indent: "  ", io: @io).emit }

  def tally
    rows = Hashira::Report::Tally.new(@findings).rows
    wide = rows.map { it.kind.length }.max
    tall = rows.first.count.to_s.length
    rows.each { @io.puts(it.line(wide, tall)) }
    @io.puts
  end
end
