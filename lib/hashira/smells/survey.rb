# frozen_string_literal: true

class Hashira::Smells::Survey
  def initialize(census, boundaries, rules)
    @census = census
    @boundaries = boundaries
    @rules = rules
  end

  def findings = @_findings ||= Hashira::Smells::Report.new(@census.types, @boundaries, @rules).findings
end
