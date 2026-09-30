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

  def payload = about.merge(base).merge(coupling).merge(sections.compact).merge(withheld)

  def about
    project = @view.project
    { version: SCHEMA, packaging: @view.graph&.packaging, targets: project.directories }
      .merge(files: project.files.size)
  end

  def base = { findings: shown(:findings).map { rendered(it) }, kinds:, accepted: }

  def kinds = Hashira::Report::Tally.new(@view.findings.all).to_h

  def rendered(finding)
    finding.to_h.merge(message: Hashira::Report::Phrases.message(finding), confidence: confidence(finding))
  end

  def confidence(finding) = Hashira::Report::Confidence.of(finding)

  def coupling
    graph = @view.graph
    graph ? Hashira::Report::GraphPayload.new(graph).to_h : {}
  end

  def lists
    @_lists ||= { findings: Hashira::Report::Spread.new(@view.findings.all).to_a }
      .merge(Hash(@view.complexity&.lists))
      .merge(duplication: @view.duplication&.clusters, hotspots: @view.hotspots&.files).compact
  end

  def shown(name)
    list = lists[name]
    cap = @view.top
    cap && list ? list.first(cap) : list
  end

  def sections
    {
      complexity: (complexity if @view.complexity),
      duplication: shown(:duplication)&.map { Hashira::Duplication::Delta.new(it).to_h },
      hotspots: shown(:hotspots)&.map(&:to_h)
    }
  end

  def accepted
    @view.findings.accepted.map { |finding, reason| rendered(finding).merge(reason:) }
  end

  def complexity = { methods: shown(:methods).map(&:to_h), classes: shown(:classes).map(&:to_h) }

  def withheld
    top = @view.top
    top ? { withheld: lists.transform_values { [it.size - top, 0].max } } : {}
  end
end
