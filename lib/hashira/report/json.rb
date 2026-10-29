# frozen_string_literal: true

require "json"

class Hashira::Report::Json
  def initialize(pieces, top, compact, io: $stdout)
    @pieces = pieces
    @top = top
    @compact = compact
    @io = io
  end

  def print
    cap = Hashira::Report::Json::Cap.new(@top)
    payload = @pieces.map { it.to_h(cap) }.reduce({}, :merge)
    @io.puts(@compact ? JSON.generate(payload) : JSON.pretty_generate(payload))
  end

  def status = 0
end
