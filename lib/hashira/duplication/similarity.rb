# frozen_string_literal: true

class Hashira::Duplication::Similarity
  def initialize(left, right)
    @left = left
    @right = right
  end

  def ratio = normalized(subsequence)

  private

  def normalized(length) = length.zero? ? 0.0 : (2.0 * length) / (@left.size + @right.size)

  def subsequence
    full = (1 << @right.size) - 1
    ones(full) - ones(@left.reduce(full) { |state, token| step(state, masks.fetch(token, 0), full) })
  end

  def step(state, mask, full)
    taken = state & mask
    ((state + taken) | (state - taken)) & full
  end

  def ones(bits) = bits.to_s(2).count("1")

  def masks
    @_masks ||= @right.each_with_index.with_object(Hash.new(0)) { |(token, index), found| found[token] |= 1 << index }
  end
end
