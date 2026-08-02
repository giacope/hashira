# frozen_string_literal: true

class Hashira::Duplication::Clones
  def initialize(project, trees, churn)
    @project = project
    @trees = trees
    @churn = churn
  end

  def clusters = @clusters ||= Hashira::Duplication::Clusters.new(fragments).sorted

  def findings = clusters.map { |cluster| Hashira::Duplication::DuplicationFinding.new(cluster, @churn).to_finding }

  private

  def fragments = Hashira::Duplication::Harvest.new(@project, @trees).fragments
end
