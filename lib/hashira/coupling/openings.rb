# frozen_string_literal: true

class Hashira::Coupling::Openings
  def initialize(rows)
    @rows = rows
  end

  def each(&) = pairs.each(&)

  def to_a = pairs.map(&:last)

  def to_h = @_to_h ||= pairs.group_by(&:first).transform_values { |found| found.map(&:last) }

  def loads?(path) = to_h.fetch(path, []).any?(&:loads?)

  def entered(anchors) = @rows.filter_map { |_node, _nesting, path, file| path if anchors.entry?(file) }.to_set

  def home(node) = places.fetch(node, []).first(1)

  def nest(node) = places.fetch(node, []).fetch(1, [])

  private

  def pairs
    @_pairs ||= @rows.map { |node, nesting, path, _file| [path, Hashira::Coupling::Relations.new(node, nesting, path)] }
  end

  def places = @_places ||= @rows.to_h { |node, nesting, path, _file| [node, [path, nesting]] }
end
