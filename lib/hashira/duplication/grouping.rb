# frozen_string_literal: true

class Hashira::Duplication::Grouping
  def initialize(group, names)
    @group = group
    @names = names
  end

  def cluster = Hashira::Duplication::Cluster.new(distinct)

  private

  def distinct
    spans = []
    @group.sort_by { [-it.shape.mass, -kin[@names[it]]] }.select do |fragment|
      span = fragment.span
      spans << span unless spans.any? { span.overlaps?(it) }
    end
  end

  def kin = @_kin ||= @group.map { @names[it] }.tally
end
