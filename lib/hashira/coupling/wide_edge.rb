# frozen_string_literal: true

require_relative "rule"

class Hashira::Coupling::WideEdge < Hashira::Coupling::Rule
  KIND = "wide_edge"

  WIDTH = 5

  class Span
    def initialize(from, to, constants)
      @from = from
      @to = to
      @constants = constants
    end

    def to_h = { from: @from, to: @to, constants: @constants }

    def phrase(_package)
      "#{@from} -> #{@to} is #{@constants.size} constants wide (#{@constants.join(", ")}) — " \
        "every one is a reason for #{@from} to change. Front #{@to} with one facade."
    end
  end

  def list
    edges.to_a.reject(&:aside?).select { wide?(it) }.map { entry(it) }
  end

  private

  def wide?(edge) = edge.constants.size >= threshold(WIDTH)

  def entry(edge)
    from, to = edge.to_a
    proof = Hashira::Analysis::Finding::Proof.new(edge.evidence.first(4))
    finding(between(from, to), Span.new(from, to, edge.constants), proof)
  end
end
