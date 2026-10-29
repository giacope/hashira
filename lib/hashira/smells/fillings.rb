# frozen_string_literal: true

require "prism"

class Hashira::Smells::Fillings
  WRITES = [Prism::InstanceVariableWriteNode, Prism::InstanceVariableOrWriteNode].freeze

  BUILD = :new

  def initialize(walked, ownership)
    @walked = walked
    @ownership = ownership
  end

  def types(name, owner)
    ancestry = @ownership.ancestry
    kin = ancestry.down(owner).flat_map { ancestry.up(it) }.uniq
    kin.flat_map { written.fetch([it, name], []) }
  end

  private

  def written
    @_written ||= @walked.flat_map { |node, full| typed(node, full.join("::")) }
      .group_by { it.first(2) }.transform_values { it.map(&:last) }
  end

  def typed(type, owner)
    Hashira::Smells::Scope.new(type).sweep.grep(Prism::DefNode).flat_map do |definition|
      nodes = Hashira::Smells::Scope.new(definition).inside
      locals = nodes.grep(Prism::LocalVariableWriteNode)
      nodes.select { WRITES.include?(it.class) }.flat_map { |write| built(write, locals, owner) }
    end
  end

  def built(write, locals, owner)
    value = write.value
    value = locals.find { it.name == value.name }&.value if value.is_a?(Prism::LocalVariableReadNode)
    return [] unless value.is_a?(Prism::CallNode) && value.name == BUILD
    [[owner, write.name, @ownership.placed(value.receiver, owner)]]
  end
end
