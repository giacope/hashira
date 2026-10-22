# frozen_string_literal: true

class Hashira::Duplication::Grouping
  def initialize(group)
    @group = group
  end

  # One site left means the copies overlap each other; Maximal keeps only clusters with two fresh sites.
  def cluster = Hashira::Duplication::Cluster.new(distinct)

  private

  def distinct
    @group.sort_by { [-it.mass, -kin[it.identifiers]] }.each_with_object([]) do |fragment, kept|
      kept << fragment unless fragment.touches?(kept)
    end
  end

  def kin = @_kin ||= @group.map(&:identifiers).tally
end
