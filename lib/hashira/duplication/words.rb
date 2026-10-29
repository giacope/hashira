# frozen_string_literal: true

require "zlib"

class Hashira::Duplication::Words
  ROWS = 2

  SEEDS = (1..20).to_a.freeze

  def initialize(vocabulary, spoken, nodes)
    @vocabulary = vocabulary
    @spoken = spoken
    @nodes = nodes
  end

  def to_a = @vocabulary

  def to_h = @spoken

  def identifiers = @nodes.filter_map { it.deconstruct_keys([:name])[:name] }

  def bands
    words = @vocabulary.uniq.map(&:to_s)
    return [] if words.empty?
    signature = SEEDS.map { |seed| words.min_by { Zlib.crc32(it, seed) } }
    signature.each_slice(ROWS).with_index.map { |rows, band| [band, *rows] }
  end
end
