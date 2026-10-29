# frozen_string_literal: true

class Hashira::Coupling::Network
  def initialize(map, tally)
    @map = map
    @tally = tally
  end

  def to_a = @_to_a ||= @tally.to_a | @map.to_h.keys

  def to_h = @_to_h ||= to_a.to_h { [it, metric(it)] }

  def to_s = @tally.to_s

  def folds = @tally.folds

  def links = @_links ||= @tally.links(to_a, @map.to_h)

  def code = @_code ||= links.to_h { |from, tos| [from, tos.reject { navigation?(from, it) }.to_set] }

  def clients(package) = to_a.select { links[it].include?(package) }.sort

  private

  def metric(package) = Hashira::Coupling::Metric.new(@tally.to_h[package], clients(package).size, links[package].size)

  def navigation?(from, to) = declares?(to, from) && @map.declarations(from, to).size == @map[from, to].size

  def declares?(from, to) = @map.declarations(from, to).any?
end
