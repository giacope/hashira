# frozen_string_literal: true

class Hashira::Complexity::Notes
  def initialize(path, comments)
    @path = path
    @comments = comments
  end

  def code?(number) = !bare(number).strip.empty?

  private

  def bare(number)
    text = lines.fetch(number - 1, "")
    text.byteslice(0, cuts.fetch(number, text.bytesize))
  end

  def lines = @_lines ||= File.binread(@path).lines

  def cuts = @_cuts ||= @comments.each_with_object({}) { |comment, found| mark(comment.location, found) }

  def mark(location, found)
    first = location.start_line
    found[first] ||= location.start_column
    ((first + 1)...location.end_line).each { found[it] = 0 }
  end
end
