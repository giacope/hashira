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
      package:, evidence: parts.flat_map do
        sightings(package, it).first(2)
      end, detail: { parts: parts.map(&:to_h) }
    )
  end

  def sightings(package, part)
    part.users.flat_map { |client| graph.evidence(client, package).to_a.select { mentions?(it, part.constants) } }
  end

  def mentions?(line, constants) = constants.any? { line.end_with?(": #{it}", "::#{it}") }
end
