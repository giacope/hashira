# frozen_string_literal: true

class Hashira::Duplication::Clones
  def initialize(paths, trees)
    @paths = paths
    @trees = trees
  end

  def clusters = @_clusters ||= Hashira::Duplication::Clusters.new(fragments).sorted

  def findings(churn) = clusters.map { Hashira::Duplication::DuplicationFinding.new(it, churn).to_finding }

  def coverage = clusters.flat_map(&:to_a).group_by { it.span.to_a.first }.transform_values { distinct(it) }

  private

  def fragments = Hashira::Duplication::Harvest.new(@paths, @trees).fragments

  def distinct(sites) = sites.flat_map { it.body.to_a }.uniq(&:object_id).size
end
