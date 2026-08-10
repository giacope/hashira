# frozen_string_literal: true

class Hashira::Report::Columns
  CAP = 48
  HEAD = 23
  GAP = "  "
  NUMBER = /\A-?\d+(?:\.\d+)?\z/

  def initialize(headers, rows, io: $stdout)
    @headers, *@rows = [headers, *rows].map { |cells| cells.map { clip(it) } }
    @io = io
  end

  def print
    @io.puts(header)
    @io.puts(rule)
    body
  end

  def body = @rows.each { @io.puts(line(it)) }

  def header = line(@headers)

  def rule = "-" * [header, *@rows.map { line(it) }].map(&:length).max

  private

  def line(cells) = cells.map.with_index { |cell, column| pad(cell, column) }.join(GAP).rstrip

  def pad(cell, column)
    width = widths[column]
    numeric[column] ? cell.rjust(width) : cell.ljust(width)
  end

  def widths = @widths ||= @headers.each_index.map { |column| down(column).map(&:length).max }

  def numeric = @numeric ||= @headers.each_index.map { |column| @rows.any? && counted?(column) }

  def counted?(column) = @rows.all? { NUMBER.match?(it[column]) }

  def down(column) = [@headers[column], *@rows.map { it[column] }]

  def clip(cell)
    text = cell.to_s
    return text if text.length <= CAP
    "#{text[0, HEAD]}…#{text[(HEAD + 1 - CAP)..]}"
  end
end
