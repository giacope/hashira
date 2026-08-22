# frozen_string_literal: true

class Hashira::Smells::Check
  def initialize(subject)
    @subject = subject
  end

  def finding
    return unless smelly?
    Hashira::Analysis::Finding.new(kind:, package: label, detail:, evidence:, sources:)
  end

  private

  attr_reader :subject

  def kind = Hashira::Smells::Kind.new(self.class).to_s

  def label = subject.subject

  def site = subject.site

  def detail = { site: }

  def spots(nodes) = "#{subject.file}:#{nodes.map { it.location.start_line }.uniq.join(", ")}"

  def evidence = []

  def sources = [subject.file]

  def tally(name, lines) = "#{name} (line#{"s" if lines.size > 1} #{lines.join(", ")})"
end
