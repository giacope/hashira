# frozen_string_literal: true

module Evaluation
  Metrics =
    Data.define(:status, :files, :thousands, :seconds, :megabytes, :kinds) do
      def to_h = super.transform_keys(&:to_s).merge("kloc" => thousands).except("thousands")
    end
end

class Evaluation::Run
  def initialize(home, outcome)
    @home = home
    @outcome = outcome
  end

  def metrics
    peak = @outcome.peak
    Evaluation::Metrics.new(
      status: @outcome.status, files: json["files"], thousands:, seconds: peak.seconds.round(2),
      megabytes: peak.megabytes, kinds:
    ).to_h
  end

  def checks(name)
    cycles = @outcome.kinds("cycle").filter_map { cut(name, it.fetch("detail")) }
    [Evaluation::Check.of(Evaluation::Corpus::SUITE, "#{name}: hashira exits 0", 0, @outcome.status), *cycles]
  end

  def sightings(name) = @outcome.findings.map { Evaluation::Sighting.new(corpus: name, finding: it, home: base) }

  private

  def json = @outcome.json

  def targets = json.fetch("targets")

  def base = targets.one? ? File.join(@home, targets.first) : @home

  def thousands = (lines / 1000.0).round(2)

  def lines = targets.sum { |target| Dir["#{@home}/#{target}/**/*.rb"].sum { counted(it) } }

  def counted(path) = File.foreach(path).count { !it.strip.empty? }

  def kinds = @outcome.findings.map { it["kind"] }.tally.sort.to_h { |kind, count| [kind, density(count)] }

  def density(count) = { "count" => count, "per_kloc" => (count / thousands).round(2) }

  def cut(name, detail)
    members = detail.fetch("members")
    optimum = Evaluation::Arcs.new(inside(members)).minimum
    label = "#{name}: cut of #{members.size}-package knot is minimum"
    Evaluation::Check.of(Evaluation::Corpus::SUITE, label, optimum, detail.fetch("cut").sum { it["weight"] }) if optimum
  end

  def inside(members)
    @outcome.edges.filter_map { |(from, to), weight| [from, to, weight] if (members & [from, to]).size == 2 }
  end
end
