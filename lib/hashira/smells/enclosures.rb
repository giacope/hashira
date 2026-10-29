# frozen_string_literal: true

class Hashira::Smells::Enclosures
  def initialize(root)
    @root = root
  end

  def of(node) = blocks.reverse.lazy.select { Hashira::Smells::Extent.new(it).covers?(node) }.first(1).map { start(it) }

  private

  def start(block) = block.location.start_offset

  def blocks = @_blocks ||= Hashira::Smells::Scope.new(@root).inside.select { Hashira::Smells::Border.new(it).closure? }
end
