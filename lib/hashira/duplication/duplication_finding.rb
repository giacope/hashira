# frozen_string_literal: true

class Hashira::Duplication::DuplicationFinding
  KIND = "duplication"

  Overlap = Data.define(:size, :mass, :kind, :hot)

  def initialize(cluster, churn)
    @cluster = cluster
    @churn = churn
  end

  def to_finding
    site = @cluster.canonical
    Hashira::Analysis::Finding.new(
      kind: KIND, package: site.location, digest: site.digest, detail:, evidence:, sources:
    )
  end

  private

  def detail
    Overlap.new(
      size: @cluster.size, mass: @cluster.mass,
      kind: Hashira::Duplication::Delta.new(@cluster).kind, hot: @churn.hot?(@cluster.sites)
    )
  end

  def evidence = @cluster.sites.sort_by(&:rank).map(&:range)

  def sources = @cluster.sites.map(&:file)
end
