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
    Hashira::Report::Tally.new(@findings).lines.each { @io.puts(it) }
    @io.puts
  end
end
