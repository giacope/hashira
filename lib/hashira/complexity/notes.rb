# frozen_string_literal: true

class Hashira::Complexity::Notes
  def initialize(parsed, path, comments)
    @parsed = parsed
    @path = path
    @comments = comments
  end

  def code?(number) = !bare(number).strip.empty?

  private

  def bare(number)
    text = lines.fetch(number - 1, "")
    text.byteslice(0, cuts.fetch(number, text.bytesize))
  end

  def lines = @_lines ||= @parsed.lines(@path)

  def cuts = @_cuts ||= @comments.reduce({}) { |found, comment| cut(found, comment.location) }

  def cut(found, location)
    first = location.start_line
    { first => location.start_column }.merge(found).merge(((first + 1)...location.end_line).to_h { [it, 0] })
  end
end
