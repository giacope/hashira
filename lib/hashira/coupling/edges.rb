# frozen_string_literal: true

class Hashira::Coupling::Edges
  def initialize(map, network, tally)
    @map = map
    @network = network
    @tally = tally
  end

  def to_a = @map.to_h.sort.flat_map { |from, tos| tos.sort.map { self[from, it] } }

  def [](from, to) = Hashira::Coupling::Edge.new(from, to, @map, @tally)

  def outgoing(package) = @map.to_h[package].to_a.sort

  def incoming(package) = @network.to_a.select { @map.to_h[it].include?(package) }.sort

  def usage(package)
    root = @tally.root
    @network.clients(package).reject { it.end_with?(root) }.to_h { [it, @map.usage(it, package)] }
  end

  def links = @map.to_a
end
