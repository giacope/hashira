# frozen_string_literal: true

class Hashira::Report::View::Layout
  def initialize(top = nil, compact = nil)
    @top = top
    @compact = compact
  end

  def page(io) = Hashira::Report::Page.new(@top, io)

  def json(pieces, io) = Hashira::Report::Json.new(pieces, @top, @compact, io:)
end
