# frozen_string_literal: true

class Evaluation::Run
  SUITE = "corpus"

  def initialize(home, outcome)
    @home = home
    @outcome = outcome
  end

  def to_h
    _, status, peak = @outcome.to_a
    told = { "status" => status, "files" => @outcome.probe("files").first }.merge(peak.to_h)
    told.merge("kinds" => kinds, "kloc" => thousands)
  end

  def checks(name)
    _, status = @outcome.to_a
    cycles = @outcome.kinds("cycle").filter_map { cut(name, it.fetch("detail")) }
    [Evaluation::Check.of(SUITE, "#{name}: hashira exits 0", 0, status), *cycles]
  end

  def sightings(name) = @outcome.findings.map { Evaluation::Sighting.new(name, it, base) }

  private

  def targets = @outcome.probe("targets").fetch(0)

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
    Evaluation::Check.of(SUITE, label, optimum, detail.fetch("cut").sum { it["weight"] }) if optimum
  end

  def inside(members)
    @outcome.edges.filter_map { |(from, to), weight| [from, to, weight] if (members & [from, to]).size == 2 }
  end
end
