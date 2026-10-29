# frozen_string_literal: true

class Hashira::CLI::Record
  BASELINE = "hashira_baseline.json"

  private_constant :BASELINE

  def self.build(recorded, home) = new(recorded.empty? ? home.join(BASELINE) : recorded, home)

  def initialize(path, home)
    @path = path
    @home = home
  end

  def accepted = Hashira::CI::Accepted.build(@path)

  def baseline(coverage, checks = Hashira::Checks.new)
    coverage.recorded(@home) { |analyzers, targets| Hashira::CI::Baseline.new(@path, analyzers:, targets:, kinds: checks.to_a) }
  end

  def project(directories, packaging, declared)
    boundaries = accepted.boundaries(declared)
    Hashira::Project.new(directories, home: @home.path, packaging:, boundaries:)
  end

  def to_h = { baseline: @path, home: @home }
end
