# frozen_string_literal: true

require_relative "rule"

class Hashira::Coupling::MixedAudienceFindings < Hashira::Coupling::Rule
  KIND = "mixed_audience"

  def list
    graph.packages.sort.filter_map { verdict(it) }
  end

  private

  def verdict(package)
    audiences = Hashira::Coupling::Audiences.new(graph.usage(package))
    detail(package, audiences.parts) if audiences.split?
  end

  def detail(package, parts)
    finding(
      package:, evidence: parts.flat_map { sightings(package, it).first(2) },
      sources: sources(package, parts), detail: { parts: parts.map(&:to_h) }
    )
  end

  def sources(package, parts)
    parts.flat_map(&:users).flat_map { graph.sources(reach(it, package)) }
  end

  def sightings(package, part)
    part.users.flat_map { |client| quotes(reach(client, package), part.constants) }
  end

  def quotes(edge, constants) = graph.evidence(edge).to_a.select { mentions?(it, constants) }

  def reach(from, to) = Hashira::Coupling::Edge.new(from, to)

  def mentions?(line, constants) = constants.any? { line.end_with?(": #{it}", "::#{it}") }
end
