# frozen_string_literal: true

class Hashira::Duplication::NearMiss
  THRESHOLD = 0.8
  MASS_RATIO = 1.5

  def initialize(fragments)
    @fragments = fragments
  end

  def pairs = Hashira::Duplication::Index.new(@fragments).buckets.flat_map { |bucket| verified(bucket) }.uniq

  private

  def verified(bucket) = bucket.combination(2).select { |left, right| near?(left, right) }

  def near?(left, right)
    return false unless comparable?(left, right) && !left.overlaps?(right)
    drifted?(left.types, right.types)
  end

  def drifted?(first, second)
    first != second && Hashira::Duplication::Similarity.new(first, second).meets?(THRESHOLD)
  end

  def comparable?(left, right)
    masses = [left.mass, right.mass]
    masses.max <= masses.min * MASS_RATIO
  end
end
