# frozen_string_literal: true

class Hashira::Coupling::Cycles
  def initialize(network, map, forward = Hashira::Coupling::Reach.new(network.code))
    @network = network
    @map = map
    @forward = forward
  end

  def path(package) = Hashira::Coupling::CycleSearch.new(@network.code, package).path

  def knots = @_knots ||= @network.to_a.sort.map { component(it) }.reject(&:empty?).uniq

  def tied?(from, to) = knots.any? { it.include?(from) && it.include?(to) }

  def cut(members) = Hashira::Coupling::Cut.new(members, inside(members), dependents(members))

  private

  def component(package) = (@forward.from(package) & Hashira::Coupling::Reach.new(backward).from(package)).sort

  def backward = @_backward ||= Hashira::Coupling::Reach.new(@network.code).inverted

  def dependents(members) = members.to_h { [it, @network.clients(it).size] }

  def inside(members) = members.flat_map { |from| links(from, members) }

  def links(from, members) = (@network.code.fetch(from, []).to_a & members).map { [from, it, @map[from, it].size] }
end
