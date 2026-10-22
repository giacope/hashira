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

  def anchors(told)
    file, lines = told.to_h[:site].to_s.split(":", 2)
    [site, *lines.to_s.split(", ").map { "#{file}:#{it}" }].uniq
  end

  def marks(found) = rating.merge(shape: (Hashira::Smells::Shape.new(subject.content).of if found.empty?))

  def tally(name, lines) = "#{name} (line#{"s" if lines.size > 1} #{lines.join(", ")})"
end
