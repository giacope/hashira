# frozen_string_literal: true

class Hashira::Duplication::Index
  RARE = 2
  CROWD = 60

  def initialize(fragments)
    @fragments = fragments
  end

  def buckets = filed(@fragments) { rarest(it.types) }.flat_map { settled(it) }.reject(&:one?)

  private

  def settled(bucket) = bucket.size > CROWD ? filed(bucket, &:bands) : [bucket]

  def filed(fragments, &) = keyed(fragments, &).group_by(&:first).values.map { it.map(&:last) }

  def keyed(fragments) = fragments.flat_map { |fragment| yield(fragment).map { [it, fragment] } }

  def counts = @_counts ||= @fragments.flat_map { it.types.uniq }.tally

  def rarest(tokens) = tokens.uniq.min_by(RARE) { counts[it] }
end
