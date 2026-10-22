# frozen_string_literal: true

class Hashira::Duplication::Similarity
  def initialize(left, right)
    @left = left
    @right = right
  end

  def ratio
    length = subsequence
    length.zero? ? 0.0 : (2.0 * length) / (@left.size + @right.size)
  end

  private

  def subsequence
    full = (1 << @right.size) - 1
    last =
      @left.reduce(full) do |state, token|
        taken = state & masks.fetch(token, 0)
        ((state + taken) | (state - taken)) & full
      end
    ones(full) - ones(last)
  end

  def ones(bits) = bits.to_s(2).count("1")

  def masks
    @_masks ||= @right.each_with_index.with_object(Hash.new(0)) { |(token, index), found| found[token] |= 1 << index }
  end
end
