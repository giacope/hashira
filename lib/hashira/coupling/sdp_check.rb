# frozen_string_literal: true

class Hashira::Coupling::SdpCheck
  MIN_EDGES = 3

  MIN_GAP = 0.1

  def initialize(dependencies, metrics)
    @dependencies = dependencies
    @metrics = metrics
  end

  def violations
    @dependencies.flat_map do |from, tos|
      tos.select { against?(from, it) }.map { [from, it] }
    end
  end

  private

  def against?(from, to) = measured?(from) && measured?(to) && gap(from, to) >= MIN_GAP

  def measured?(package) = @metrics[package].degree >= MIN_EDGES

  def gap(from, to) = (@metrics[to].level - @metrics[from].level).round(2)
end
