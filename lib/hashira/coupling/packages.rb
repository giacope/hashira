# frozen_string_literal: true

class Hashira::Coupling::Packages
  def initialize(network, map, unfolded)
    @network = network
    @map = map
    @unfolded = unfolded
  end

  def to_a = @network.to_a

  def to_h = @network.to_h

  def to_s = @network.to_s

  def folds = @network.folds

  def cycles = Hashira::Coupling::Cycles.new(@network, @map)

  def violations
    found = cycles
    Hashira::Coupling::SdpCheck.new(@network.links, to_h).violations.reject { found.tied?(*it) || paired?(*it) }
  end

  def folded(members) = (members & folds.map { it.to_h[:to] }).reject { @unfolded.call.packages.cycles.path(it) }

  private

  def paired?(from, to) = declares?(from, to) && declares?(to, from)

  def declares?(from, to) = @map.declarations(from, to).any?
end
