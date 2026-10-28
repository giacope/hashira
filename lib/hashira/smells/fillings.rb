# frozen_string_literal: true

require "prism"

class Hashira::Smells::Fillings
  WRITES = [Prism::InstanceVariableWriteNode, Prism::InstanceVariableOrWriteNode].freeze

  MIXINS = %i[include prepend].freeze

  BUILD = :new

  def initialize(walked, ownership)
    @walked = walked
    @ownership = ownership
  end

  def types(name, owner)
    up = ties.group_by(&:first).transform_values { it.map(&:last) }
    down = ties.group_by(&:last).transform_values { it.map(&:first) }
    kin = climb(owner, down).flat_map { climb(it, up) }.uniq
    kin.flat_map { written.fetch([it, name], []) }
  end

  private

  def climb(name, edges)
    found = [name]
    found.each { found.concat(edges.fetch(it, []) - found) }
  end

  def ties
    @_ties ||= @walked.flat_map do |node, full|
      owner = full.join("::")
      above(node).map { [owner, @ownership.placed(it, owner)] }
    end.select(&:last)
  end

  def above(node)
    calls = Hashira::Smells::Scope.new(node).sweep.grep(Prism::CallNode)
    mixed = calls.select { Hashira::Analysis::Syntax.new(it).macro?(MIXINS) }.flat_map { it.arguments.arguments }
    [*(node.superclass if node.is_a?(Prism::ClassNode)), *mixed]
  end

  def written
    @_written ||= @walked.flat_map { |node, full| typed(node, full.join("::")) }
      .group_by { it.first(2) }.transform_values { it.map(&:last) }
  end

  def typed(type, owner)
    Hashira::Smells::Scope.new(type).sweep.grep(Prism::DefNode).flat_map do |definition|
      nodes = Hashira::Smells::Scope.new(definition).inside
      locals = nodes.grep(Prism::LocalVariableWriteNode)
      nodes.select { WRITES.include?(it.class) }.filter_map { |write| built(write, locals, owner) }
    end
  end

  def built(write, locals, owner)
    value = write.value
    value = locals.find { it.name == value.name }&.value if value.is_a?(Prism::LocalVariableReadNode)
    [owner, write.name, @ownership.placed(value.receiver, owner)] if value.is_a?(Prism::CallNode) && value.name == BUILD
  end
end
