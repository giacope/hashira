# frozen_string_literal: true

class Hashira::Duplication::Index
  RARE = 2
  MAX_BUCKET = 60

  def initialize(fragments)
    @fragments = fragments
  end

  def buckets = grouped.values.select { |bucket| bucket.size.between?(2, MAX_BUCKET) }

  private

  def frequency = @frequency ||= frequencies(@fragments)

  def frequencies(fragments)
    fragments.each_with_object(Hash.new(0)) { |fragment, counts| tally(counts, fragment) }
  end

  def tally(counts, fragment) = fragment.types.uniq.each { |type| counts[type] += 1 }

  def grouped
    index = Hash.new { |hash, type| hash[type] = [] }
    @fragments.each { |fragment| file(index, fragment) }
    index
  end

  def file(index, fragment) = rarest(fragment).each { |type| index[type] << fragment }

  def rarest(fragment) = fragment.types.uniq.min_by(RARE) { frequency[it] }
end
