# frozen_string_literal: true

require_relative "rule"

class Hashira::Coupling::MixedAudience < Hashira::Coupling::Rule
  KIND = "mixed_audience"

  class Split
    BASE = ", keeping the shared constants as the base layer the rest builds on"

    def initialize(parts)
      @parts = parts
    end

    def to_h = { parts: @parts.map(&:to_h) }

    def phrase(package)
      "#{package} splits #{@parts.size} ways: #{@parts.join("; ")} — " \
        "parts with separate client bases are separate packages in disguise. " \
        "Split #{package} along that seam#{BASE if @parts.any?(&:shared?)}."
    end
  end

  def list
    graph.packages.sort.filter_map { verdict(it) }
  end

  private

  def verdict(package)
    audiences = Hashira::Coupling::Audiences.new(graph.usage(package), sizes)
    detail(package, audiences.parts) if audiences.split?
  end

  def sizes = @_sizes ||= metrics.transform_values(&:types)

  def detail(package, parts)
    sighted(package, Split.new(parts), parts.flat_map { it.sightings(package, graph).first(2) })
  end
end
