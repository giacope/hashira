# frozen_string_literal: true

class Hashira::Report::Json::Hotspots
  def initialize(rollup)
    @rollup = rollup
  end

  def to_h(cap) = { hotspots: cap.call(@rollup.files).map(&:to_h) }

  def lists = { hotspots: @rollup.files }
end
