# frozen_string_literal: true

class Hashira::Smells::Enclosures
  def initialize(root)
    @root = root
  end

  def of(node) = Array(blocks.reverse.find { Hashira::Smells::Extent.new(it).covers?(node) }).map { start(it) }

  private

  def start(block) = block.location.start_offset

  def blocks = @_blocks ||= Hashira::Smells::Scope.new(@root).inside.select { Hashira::Smells::Border.new(it).closure? }
end
