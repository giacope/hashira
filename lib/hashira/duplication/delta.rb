# frozen_string_literal: true

class Hashira::Duplication::Delta
  ADVICE = {
    identical: "byte-for-byte identical — extract a shared method and call it from each site.",
    literal: "differs only in literal values — extract a method, pass them as arguments.",
    message: "differs only in the receiver or message — extract a method taking the receiver.",
    constant: "differs only in a constant — extract a method and parameterize it.",
    structure: "the control flow differs — extract the common core, but verify by hand (lower confidence).",
    mixed: "extract the shared shape and pass what differs as parameters."
  }.freeze

  def initialize(cluster)
    @cluster = cluster
  end

  def summary = ADVICE.fetch(kind)

  def kind
    tags = kinds
    return :identical if tags.empty?
    return :structure if tags.include?(:structure)
    tags.size == 1 ? tags.first : :mixed
  end

  def to_h
    {
      mass: @cluster.mass, sites: @cluster.size, kind:,
      locations: @cluster.sites.sort_by(&:rank).map(&:range)
    }
  end

  private

  def kinds
    @cluster.others.flat_map { |other| Hashira::Duplication::Variance.new(@cluster.canonical, other).kinds }.uniq
  end
end
