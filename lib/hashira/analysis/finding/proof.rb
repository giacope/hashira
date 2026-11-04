# frozen_string_literal: true

class Hashira::Analysis::Finding::Proof
  TRACKS = [/ \(lines? [\d, ]+\)/, /:[\d, -]+\z/, /:\d+(?=:)/].freeze

  DOUBT = :low

  def initialize(evidence, anchors = [], shapes = [], ratings = [])
    @evidence = evidence
    @anchors = anchors
    @shapes = shapes
    @ratings = ratings
  end

  def to_a = @evidence

  def trace(kind, site) = "#{kind}|#{plain(site)}|#{told.join(";")}"

  def confidence(inferred) = [*@ratings.map(&:to_s), inferred].fetch(0)

  def doubted? = @ratings.include?(DOUBT)

  def silence(kind, directives)
    matched = @anchors.filter_map { |anchor| [anchor, directives.find { it.covers?(kind, anchor) }] }.select(&:last)
    hushed = matched.map(&:first)
    rest = @evidence.reject { hushed.include?(start(it)) }
    starts = rest.map { start(it) }
    kept = Hashira::Analysis::Finding::Proof.new(rest, starts, @shapes, @ratings)
    Hashira::Analysis::Silence.new(matched.map(&:last), kept, starts)
  end

  private

  def told = @evidence.empty? ? @shapes : @evidence.map { plain(it) }

  def plain(text) = TRACKS.reduce(text) { |left, mark| left.gsub(mark, "") }

  def start(range) = range.sub(/-\d+\z/, "")
end
