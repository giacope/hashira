# frozen_string_literal: true

class Hashira::Smells::Kinds
  include Enumerable

  def initialize(checks = [Hashira::Smells::BoundarySprawl, *Hashira::Smells::Check.subclasses])
    @checks = checks
  end

  def each(&) = @checks.map { Hashira::Smells::Kind.new(it).to_s }.sort.each(&)
end
