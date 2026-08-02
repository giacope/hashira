# frozen_string_literal: true

class Hashira::Smells::Check
  def initialize(subject)
    @subject = subject
  end

  def finding
    return unless smelly?
    Hashira::Analysis::Finding.new(kind:, package: label, message:, evidence:)
  end

  private

  attr_reader :subject

  def kind = self.class.name.split("::").last.gsub(/(?<=[a-z])(?=[A-Z])/, "_").downcase

  def label = subject.subject

  def site = subject.site

  def evidence = []

  def tally(name, lines) = "#{name} (line#{"s" if lines.size > 1} #{lines.join(", ")})"
end
