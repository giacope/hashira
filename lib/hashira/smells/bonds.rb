# frozen_string_literal: true

require "prism"

class Hashira::Smells::Bonds
  def initialize(nodes)
    @nodes = nodes
  end

  def field(name) = :"@#{held(name, Set[])}"

  private

  def held(name, seen) = links.key?(name) && seen.add?(name) ? held(links[name], seen) : name

  def links = @_links ||= @nodes.grep(Prism::CallNode).flat_map { Hashira::Smells::Bond.new(it).pairs }.to_h
end
