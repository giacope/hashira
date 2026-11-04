# frozen_string_literal: true

class Hashira::Analysis::Finding::Name
  def initialize(package, digests = [], cycles = [])
    @package = package
    @digests = digests
    @cycles = cycles
  end

  def to_s = @package

  def to_h = { package: @package, cycle: @cycles.first, digest: @digests.first }

  def identity = [*@digests, @package].fetch(0)

  def traced(trace) = @digests.empty? ? [trace] : []

  def renamed(package) = Hashira::Analysis::Finding::Name.new(package, @digests, @cycles)
end
