# frozen_string_literal: true

class Hashira::Duplication::Grouping
  def initialize(group)
    @group = group
  end

  def cluster = Hashira::Duplication::Cluster.new(distinct)

  private

  def distinct
    @group.sort_by { [-it.shape.mass, -kin[it.words.identifiers]] }.each_with_object([]) do |fragment, kept|
      span = fragment.span
      kept << fragment unless kept.any? { span.overlaps?(it.span) }
    end
  end

  def kin = @_kin ||= @group.map { it.words.identifiers }.tally
end
