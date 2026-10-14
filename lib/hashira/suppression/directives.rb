# frozen_string_literal: true

class Hashira::Suppression::Directives
  PREFIX = /\A#\s*hashira:/

  SHAPE = /\A#\s*hashira:(?<verb>\S+)\s+(?<kinds>[^-]*?)\s*(?:--\s*(?<reason>.*?))?\s*\z/

  VERBS = { "disable" => :trailing, "disable-next-line" => :following }.freeze

  def initialize(file, comments, lines, kinds)
    @file = file
    @comments = comments
    @lines = lines
    @kinds = kinds
  end

  def to_a = @comments.select { PREFIX.match?(it.slice) }.map { read(it) }

  private

  def read(comment)
    line = comment.location.start_line
    parts = SHAPE.match(comment.slice) || refuse(line, "reads hashira:VERB KIND[,KIND] -- REASON")
    kinds = vetted(line, parts)
    target = __send__(VERBS.fetch(parts[:verb]), comment, line)
    Hashira::Suppression::Directive.new(file: @file, line:, target:, kinds:, reason: parts[:reason])
  end

  def vetted(line, parts)
    verb = parts[:verb]
    refuse(line, "#{verb} is not a directive (use: #{VERBS.keys.join(", ")})") unless VERBS.key?(verb)
    refuse(line, "needs a reason after --") if parts[:reason].to_s.empty?
    kinds(line, parts[:kinds].split(/[\s,]+/))
  end

  def kinds(line, named)
    unknown = named - @kinds
    refuse(line, "names no kind") if named.empty?
    refuse(line, "names unknown kind #{unknown.first.inspect} (use: #{@kinds.join(", ")})") unless unknown.empty?
    named
  end

  def following(_comment, line) = next_code(line) || raise(Hashira::Error, "#{at(line)} has no line of code after it")

  def trailing(comment, line)
    return line if comment.trailing?
    raise(Hashira::Error, "#{at(line)} disable sits on the line it silences; above a line, use disable-next-line")
  end

  def next_code(line) = ((line + 1)..@lines.size).find { code?(@lines[it - 1]) }

  def code?(text) = !text.strip.empty? && !text.lstrip.start_with?("#")

  def refuse(line, problem) = raise(Hashira::Error, "#{at(line)} #{problem}")

  def at(line) = "#{@file}:#{line}: hashira: directive"
end
