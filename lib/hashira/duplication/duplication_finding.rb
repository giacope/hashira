# frozen_string_literal: true

class Hashira::Duplication::DuplicationFinding
  def initialize(cluster, churn)
    @cluster = cluster
    @churn = churn
  end

  def to_finding
    site = @cluster.canonical
    Hashira::Analysis::Finding.new(
      kind: "duplication", package: site.location, digest: site.digest,
      cycle: nil, message:, evidence:
    )
  end

  private

  def message
    "#{@cluster.size} similar fragments (mass #{@cluster.mass}) — #{Hashira::Duplication::Delta.new(@cluster).summary}#{note}"
  end

  def evidence = @cluster.sites.sort_by(&:rank).map(&:range)

  def note
    @churn.hot?(@cluster.sites) ? " Both sites change often — fix one, miss the other." : ""
  end
end
