# frozen_string_literal: true

class Hashira::Smells::Extent
  def initialize(node)
    @node = node
  end

  def covers?(node) = stretch.cover?(Hashira::Smells::Extent.new(node).stretch)

  protected

  def stretch
    spot = @node.location
    spot.start_offset..spot.end_offset
  end
end
