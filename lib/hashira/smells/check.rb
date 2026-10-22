# frozen_string_literal: true

class Hashira::Smells::Check
  def initialize(subject, rules)
    @subject = subject
    @rules = rules
  end

  def finding
    return unless smelly?
    found = evidence
    told = detail
    Hashira::Analysis::Finding.new(
      kind:, package: label, detail: told, evidence: found, anchors: anchors(told), **marks(found)
    )
  end

  private

  attr_reader :subject

  def kind = Hashira::Smells::Kind.new(self.class).to_s

  def threshold(default) = @rules.threshold(kind, default)

  def label = subject.subject

  def site = subject.site

  def detail = { site: }

  def spots(nodes) = "#{subject.file}:#{nodes.map { it.location.start_line }.uniq.join(", ")}"

  def evidence = []

  def rating = {}

  def anchors(told) = [site, *spread(told.to_h[:site].to_s)].uniq

  def spread(spot)
    file, lines = spot.split(":", 2)
    lines.to_s.split(", ").map { "#{file}:#{it}" }
  end

  def marks(found) = rating.merge(shape: (shape if found.empty?))

  def shape = Hashira::Smells::Shape.new(subject.content).of

  def tally(name, lines) = "#{name} (line#{"s" if lines.size > 1} #{lines.join(", ")})"
end
