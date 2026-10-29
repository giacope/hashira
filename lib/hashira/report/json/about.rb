# frozen_string_literal: true

class Hashira::Report::Json::About
  SCHEMA = 1

  def initialize(graph, project)
    @graph = graph
    @project = project
  end

  def to_h(_cap) = { version: SCHEMA, packaging: @graph&.packaging, targets: @project.directories, files: files }

  def lists = {}

  private

  def files = @project.files.size
end
