# frozen_string_literal: true

require "json"

class Hashira::Report::Json
  def initialize(view, io: $stdout)
    @view = view
    @io = io
  end

  SCHEMA = 1

  def print
    payload = about.merge(base).merge(coupling).merge(sections.compact).merge(withheld).merge(unjudged)
    @io.puts(@view.compact ? JSON.generate(payload) : JSON.pretty_generate(payload))
  end

  def status = 0

  private

  def about
    project = @view.project
    { version: SCHEMA, packaging: @view.graph&.packaging, targets: project.directories }
      .merge(files: project.files.size)
  end

  def base
    kinds = Hashira::Report::Tally.new(@view.findings.to_a).to_h
    { findings: shown(:findings).map { rendered(it) }, kinds:, accepted: }.merge(suppressed)
  end

  def suppressed
    silenced = @view.suppressed.map { |finding, note| rendered(finding).merge(site: note.site, reason: note.reason) }
    { suppressed: silenced, unused_suppressions: @view.screened.unused.map(&:to_h) }
  end

  def rendered(finding) = finding.to_h

  def coupling
    graph = @view.graph
    graph ? Hashira::Report::GraphPayload.new(graph).to_h : {}
  end

  def lists
    @_lists ||= { findings: Hashira::Report::Spread.new(@view.findings.to_a).to_a }
      .merge(Hash(@view.complexity&.to_h))
      .merge(duplication: @view.duplication&.clusters, hotspots: @view.hotspots&.files).compact
  end

  def shown(name)
    list = lists[name]
    cap = @view.top
    cap && list ? list.first(cap) : list
  end

  def sections
    {
      complexity: ({ methods: shown(:methods).map(&:to_h), classes: shown(:classes).map(&:to_h) } if @view.complexity),
      duplication: shown(:duplication)&.map { Hashira::Duplication::Delta.new(it).to_h },
      hotspots: shown(:hotspots)&.map(&:to_h)
    }
  end

  def accepted
    @view.findings.to_h.map { |finding, reason| rendered(finding).merge(reason:) }
  end

  def unjudged
    told = @view.unjudged.to_a
    told.empty? ? {} : { unjudged: told }
  end

  def withheld
    top = @view.top
    top ? { withheld: lists.transform_values { [it.size - top, 0].max } } : {}
  end
end
