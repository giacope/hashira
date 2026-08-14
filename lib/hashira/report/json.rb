# frozen_string_literal: true

require "json"

class Hashira::Report::Json
  def initialize(view, io: $stdout)
    @view = view
    @io = io
  end

  SCHEMA = 1

  def print
    @io.puts(@view.compact ? JSON.generate(payload) : JSON.pretty_generate(payload))
    0
  end

  private

  def payload = about.merge(base).merge(coupling).merge(sections.compact)

  def about
    project = @view.project
    { version: SCHEMA, packaging: @view.graph&.packaging, targets: project.directories }
      .merge(files: project.files.size)
  end

  def base = { findings: @view.findings.all.map { rendered(it) }, accepted: accepted }

  def rendered(finding) = finding.to_h.merge(message: Hashira::Report::Phrases.message(finding))

  def coupling
    graph = @view.graph
    graph ? Hashira::Report::GraphPayload.new(graph).to_h : {}
  end

  def sections
    {
      complexity: (complexity if @view.complexity),
      duplication: (duplication if @view.duplication),
      hotspots: @view.hotspots&.files&.map(&:to_h)
    }
  end

  def accepted
    @view.findings.accepted.map { |finding, reason| rendered(finding).merge(reason:) }
  end

  def complexity = { methods: the_methods, classes: the_classes }

  def the_methods = @view.complexity.ranked.map(&:to_h)

  def the_classes = @view.complexity.classes.map(&:to_h)

  def duplication = @view.duplication.clusters.map { Hashira::Duplication::Delta.new(it).to_h }
end
