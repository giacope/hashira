# frozen_string_literal: true

class Hashira::Smells::Survey
  def initialize(census, boundaries, rules)
    @census = census
    @boundaries = boundaries
    @rules = rules
  end

  def findings = @_findings ||= @census.report(@boundaries, @rules).findings
end
