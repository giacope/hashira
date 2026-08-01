# frozen_string_literal: true

class Hashira::Duplication::Similarity
  def initialize(left, right)
    @left = left
    @right = right
  end

  def ratio
    return 0.0 if @left.empty? || @right.empty?
    normalized(lcs)
  end

  def meets?(threshold) = ceiling >= threshold && ratio >= threshold

  private

  def ceiling = normalized(overlap)

  def normalized(length) = (2.0 * length) / (@left.size + @right.size)

  def overlap
    @left.count { taken?(@right.tally, it) }
  end

  def taken?(counts, token)
    return false unless counts.fetch(token, 0).positive?
    counts[token] -= 1
    true
  end

  def lcs = @left.reduce(blank) { |prev, token| advance(prev, token) }.last

  def blank = Array.new(@right.size + 1, 0)

  def advance(prev, token)
    @right.each_index.reduce([0]) { |row, index| row << cell(prev, row, token, index) }
  end

  def cell(prev, row, token, index)
    @right[index] == token ? prev[index] + 1 : [prev[index + 1], row[index]].max
  end
end
