# frozen_string_literal: true

class Hashira::Duplication::Clones
  def initialize(project, trees, churn)
    @project = project
    @trees = trees
    @churn = churn
  end

  def clusters = @_clusters ||= Hashira::Duplication::Clusters.new(fragments).sorted

  def findings = clusters.map { |cluster| Hashira::Duplication::DuplicationFinding.new(cluster, @churn).to_finding }

  def coverage = clusters.flat_map(&:to_a).group_by { it.span.to_a.first }.transform_values { distinct(it) }

  private

  def fragments = Hashira::Duplication::Harvest.new(@project, @trees).fragments

  def distinct(sites) = sites.flat_map { it.body.to_a }.uniq(&:object_id).size
end
