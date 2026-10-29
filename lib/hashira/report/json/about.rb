# frozen_string_literal: true

class Hashira::Report::Json::About
  SCHEMA = 1

  def initialize(graphs, paths, listing)
    @graphs = graphs
    @paths = paths
    @listing = listing
  end

  def to_h(_cap) = { version: SCHEMA, packaging: @graphs.map(&:packaging).first, targets: @paths.to_a, files: files }

  def lists = {}

  private

  def files = @listing.to_a.size
end
