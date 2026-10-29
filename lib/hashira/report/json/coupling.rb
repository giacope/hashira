# frozen_string_literal: true

class Hashira::Report::Json::Coupling
  def initialize(graph)
    @graph = graph
  end

  def to_h(_cap) = Hashira::Report::GraphPayload.new(@graph).to_h

  def lists = {}
end
