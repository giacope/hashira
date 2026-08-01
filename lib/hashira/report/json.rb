# frozen_string_literal: true

require "json"

class Hashira::Report::Json
  def initialize(view, io: $stdout)
    @view = view
    @io = io
  end

  def print
    @io.puts(JSON.pretty_generate(payload))
    0
  end

  private

  def payload = base.merge(coupling).merge(sections.compact)

  def base = { findings: @view.findings.all.map(&:to_h), accepted: accepted }

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
    @view.findings.accepted.map { |finding, reason| finding.to_h.merge(reason:) }
  end

  def complexity = { methods: the_methods, classes: the_classes }

  def the_methods = @view.complexity.methods.map(&:to_h)

  def the_classes = @view.complexity.classes.map(&:to_h)

  def duplication = @view.duplication.clusters.map { Hashira::Duplication::Delta.new(it).to_h }
end
