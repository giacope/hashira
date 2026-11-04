# frozen_string_literal: true

class Hashira::Smells::Check
  def self.build(subject, rules, _family) = new(subject, rules)

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

  def kind = @_kind ||= Hashira::Smells::Kind.new(self.class).to_s

  def threshold(default) = @rules.limit(kind, "threshold", default)

  def strict? = @rules.strict?

  def label = subject.to_s

  def site = subject.spot.site

  def spots(nodes) = subject.spot.at(nodes.map { it.location.start_line })

  def evidence = []

  def ratings = []

  def anchors(spot)
    file, lines = spot.split(":", 2)
    [site, *lines.to_s.split(", ").map { "#{file}:#{it}" }].uniq
  end

  def shapes = [subject.spot.shape]

  def owned = subject.flat_map { |opening| opening.reject { it.standing.singleton? } }

  def selector(method) = method.accept(Hashira::Smells::Signature).name

  def tally(name, lines) = "#{name} (line#{"s" if lines.size > 1} #{lines.join(", ")})"
end
