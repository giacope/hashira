# frozen_string_literal: true

class Hashira::Duplication::DuplicationFinding
  def initialize(cluster, churn)
    @cluster = cluster
    @churn = churn
  end

  def to_finding
    site = @cluster.canonical
    Hashira::Analysis::Finding.new(kind: "duplication", package: site.location, digest: site.digest, detail:, evidence:)
  end

  private

  def detail
    {
      size: @cluster.size, mass: @cluster.mass,
      kind: Hashira::Duplication::Delta.new(@cluster).kind, hot: @churn.hot?(@cluster.sites)
    }
  end

  def evidence = @cluster.sites.sort_by(&:rank).map(&:range)
end
