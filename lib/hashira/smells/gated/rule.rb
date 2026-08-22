# frozen_string_literal: true

require_relative "../kind"

class Hashira::Smells::Gated::Rule
  def initialize(family, trees)
    @family = family
    @trees = trees
  end

  private

  attr_reader :family, :trees

  def kind = Hashira::Smells::Kind.new(self.class).to_s

  def finding(package:, detail:, evidence:, sources:)
    Hashira::Analysis::Finding.new(kind:, package:, detail:, evidence:, sources:)
  end
end
