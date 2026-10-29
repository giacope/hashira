# frozen_string_literal: true

class Hashira::Smells::Check
  def self.build(subject, rules) = new(subject, rules)

  def initialize(subject, rules)
    @subject = subject
    @rules = rules
  end

  def findings
    return [] unless smelly?
    found = evidence
    told = detail
    proof = Hashira::Analysis::Finding::Proof.new(found, anchors(told.to_h[:site].to_s), shapes, ratings)
    [Hashira::Analysis::Finding.new(kind, Hashira::Analysis::Finding::Name.new(label), told, proof)]
  end

  def members = []

  private

  def member(section, key, part, testimony) = Hashira::Smells::Member.new(section, key, [part], testimony)

  def testimony(lines, extra, anchors) = Hashira::Smells::Testimony.new(lines, extra, anchors, ratings)

  def cited(lines, spot) = testimony(lines, [], anchors(spot))

  attr_reader :subject

  def kind = Hashira::Smells::Kind.new(self.class).to_s

  def threshold(default) = @rules.threshold(kind, default)

  def strict? = @rules.strict?

  def label = subject.subject

  def site = subject.site

  def spots(nodes) = "#{subject.file}:#{nodes.map { it.location.start_line }.uniq.join(", ")}"

  def evidence = []

  def ratings = []

  def anchors(spot)
    file, lines = spot.split(":", 2)
    [site, *lines.to_s.split(", ").map { "#{file}:#{it}" }].uniq
  end

  def shapes = [Hashira::Smells::Shape.new(subject.content)]

  def tally(name, lines) = "#{name} (line#{"s" if lines.size > 1} #{lines.join(", ")})"
end
