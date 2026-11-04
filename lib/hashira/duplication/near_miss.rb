# frozen_string_literal: true

class Hashira::Duplication::NearMiss
  MASS_RATIO = 1.5

  def initialize(fragments)
    @fragments = fragments
  end

  def pairs
    opened = @fragments.select { Hashira::Duplication::Statements.new(it.to_a).opened? }.uniq { it.span.range }
    Hashira::Duplication::Index.new(opened).buckets.flat_map { verified(it) }
  end

  private

  def seen = @_seen ||= Set.new

  def verified(bucket)
    sized = bucket.sort_by { it.shape.mass }
    sized.each_with_index.flat_map { |left, index| window(sized, index).map { [left, it] }.select { kept?(it) } }
  end

  def window(sized, index)
    ceiling = sized[index].shape.mass * MASS_RATIO
    sized.drop(index + 1).take_while { it.shape.mass <= ceiling }
  end

  def kept?(pair) = seen.add?(pair.map(&:object_id).minmax) && Hashira::Duplication::Pair.new(*pair).near?
end
