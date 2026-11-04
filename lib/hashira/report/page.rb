# frozen_string_literal: true

class Hashira::Report::Page
  def initialize(top, io)
    @top = top
    @io = io
  end

  def table(kind, subject) = kind.new(subject, top: @top || kind::TOP, io: @io).print

  def puts(text) = @io.puts(text)

  def waived(title, pairs) = Hashira::Report::Listing.new(@io).waived(title, pairs)

  def silenced(screened) = Hashira::Report::Silenced.new(screened, io: @io).print
end
