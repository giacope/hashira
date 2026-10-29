# frozen_string_literal: true

class Hashira::Report::Json::Duplication
  def initialize(clones)
    @clones = clones
  end

  def to_h(cap) = { duplication: cap.call(@clones.clusters).map { Hashira::Duplication::Delta.new(it).to_h } }

  def lists = { duplication: @clones.clusters }
end
