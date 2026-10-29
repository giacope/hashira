# frozen_string_literal: true

class Hashira::Coupling::Ancestor
  def initialize(segments, nesting)
    @segments = segments
    @nesting = nesting
  end

  def to_a = [@segments, @nesting]

  def reach = @segments.length
end
