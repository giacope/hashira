# frozen_string_literal: true

class Hashira::Duplication::Analyzer
  def initialize(project, trees, churn)
    @project = project
    @trees = trees
    @churn = churn
  end

  def clusters = @clusters ||= Hashira::Duplication::Clusterer.new(fragments).clusters.sort_by { -it.mass }

  def findings = clusters.map { |cluster| Hashira::Duplication::DuplicationFinding.new(cluster, @churn).to_finding }

  private

  def fragments = Hashira::Duplication::Extractor.new(@project, @trees).fragments
end
