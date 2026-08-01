# frozen_string_literal: true

class Hashira::Duplication::Grouping
  def initialize(group)
    @group = group
  end

  def cluster
    sites = distinct
    Hashira::Duplication::Cluster.new(sites) if sites.size >= 2
  end

  private

  def distinct
    @group.sort_by { -it.mass }.each_with_object([]) do |fragment, kept|
      kept << fragment unless fragment.touches?(kept)
    end
  end
end
