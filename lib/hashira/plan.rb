# frozen_string_literal: true

require_relative "constraints/declarations"
require_relative "coupling/report"
require_relative "smells/report"

class Hashira::Plan
  ANALYZERS = %i[coupling complexity duplication smells].freeze

  STRUCTURAL = Hashira::Coupling::Report::RULES.map { it::KIND }.freeze

  SMELLS = (
    Hashira::Smells::Report::CHECKS.map { Hashira::Smells::Kind.new(it).to_s } +
      [Hashira::Smells::BoundarySprawl::KIND] + Hashira::Smells::Gated::Report::KINDS
  ).sort.freeze

  BARE = Hashira::Constraints::Declarations::NONE

  def initialize(enabled: ANALYZERS, packaging: :auto, only: [], constraints: BARE)
    @enabled = enabled
    @packaging = packaging
    @only = only
    @constraints = constraints
  end

  attr_reader :only, :constraints

  WHOLE = new

  def pipeline(project) = Hashira::Pipeline.new(project, self)

  def enabled?(analyzer) = @enabled.include?(analyzer)

  def settled(project) = @packaging == :auto ? auto(project) : @packaging

  private

  def auto(project) = project.rails? ? :namespace : :folder
end
