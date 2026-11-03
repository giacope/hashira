# frozen_string_literal: true

class Hashira::Smells::Names
  def initialize(ownership, constants)
    @ownership = ownership
    @constants = constants
  end

  def place(segments, owner, rooted: false) = @ownership.place(segments, owner, rooted:)

  def owns?(node, owner) = @ownership.placed(node, owner).any?

  def answers?(node, owner)
    placed = @ownership.placed(node, owner)
    placed.any? && !@constants.literal?(placed.fetch(0))
  end

  def keys(segments) = @constants.keys(segments)
end
