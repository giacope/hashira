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

  def baseline(pipeline, checks = Hashira::Checks.new)
    analyzers = checks.analyzers.select { pipeline.enabled?(it) }
    Hashira::CI::Baseline.new(@path, analyzers:, targets: pipeline.targets(@home), kinds: checks.to_a)
  end

  def project(directories, rules)
    boundaries = accepted.boundaries(rules.boundaries)
    Hashira::Project.new(directories, boundaries:, home: @home.path, rules:)
  end

  def to_h = { baseline: @path, home: @home }
end
