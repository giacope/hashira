# frozen_string_literal: true

require_relative "../kind"

class Hashira::Smells::Gated::Rule
  def initialize(family, trees)
    @family = family
    @trees = trees
  end

  def list = family.types.flat_map { survey(it) }

  private

  attr_reader :family, :trees

  def survey(type)
    return [] unless family.visible?(type)
    subjects(type).filter_map { entry(type, it) }
  end

  def kind = Hashira::Smells::Kind.new(self.class).to_s

  def about(subject, kin, evidence, **extra)
    finding(**located(subject), evidence:, detail: told(subject, kin, extra))
  end

  def located(subject) = { package: subject.subject, sources: [subject.file] }

  def told(subject, kin, extra) = { site: subject.site, owners: kin.map(&:owner).uniq }.merge(extra)

  def finding(package:, detail:, evidence:, sources:)
    Hashira::Analysis::Finding.new(kind:, package:, detail:, evidence:, sources:)
  end
end
