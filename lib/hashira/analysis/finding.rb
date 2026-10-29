# frozen_string_literal: true

class Hashira::Analysis::Finding
  CLONES = "duplication"

  MAGNITUDES = { "duplication" => :mass, "boundary_sprawl" => :count }
    .merge("complexity" => :cognitive, "indirection" => :chain, "fragmentation" => :helpers)
    .merge("layer_violation" => :refs).freeze

  ORDER = %i[kind package detail evidence cycle digest].freeze

  private_constant :CLONES, :MAGNITUDES, :ORDER

  def initialize(kind, name, detail, proof)
    @kind = kind
    @name = name
    @detail = detail
    @proof = proof
  end

  def of?(kinds) = kinds.include?(@kind)

  def scored(medium)
    trace = @proof.trace(@kind, site)
    medium.call("#{@kind}:#{@name.identity}", magnitudes.first, @name.traced(trace))
  end

  def quotes = [@name.to_s, *sites, *@proof.to_a]

  def silenced(directives)
    silence = @proof.silence(@kind, directives)
    return silence.kept(self) unless of?([CLONES])
    silence.trimmed(self) do |rest, lead, size|
      Hashira::Analysis::Finding.new(@kind, @name.renamed(lead), @detail.resized(size), rest)
    end
  end

  def to_h
    told = { kind: @kind, **@name.to_h, detail: @detail.to_h, evidence: @proof.to_a }
    told.slice(*ORDER).compact.merge(message:, confidence: @proof.confidence(inferred))
  end

  def to_s = "#{@kind}/#{@name}"

  def to_a = ["#{@kind}: #{message}", *@proof.to_a]

  def <=>(other) = rank <=> other.rank

  protected

  def rank = [@proof.doubted? ? 1 : 0, -magnitudes.sum]

  private

  def magnitudes = [@detail.to_h[MAGNITUDES[@kind]]].compact

  def sites = [@detail.to_h[:site]].compact

  def site = sites.join

  def message = @detail.phrase(@name.to_s)

  def inferred = Hashira::Analysis::Confidence.new(@kind, @detail).to_s
end
