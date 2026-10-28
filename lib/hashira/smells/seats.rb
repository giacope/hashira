# frozen_string_literal: true

require "prism"

class Hashira::Smells::Seats
  SLOTS = %i[
    class_attribute mattr_accessor mattr_reader cattr_accessor cattr_reader thread_mattr_accessor thread_cattr_accessor
  ].freeze

  FOLDS = %i[inject reduce].freeze

  DEFAULT = "default"

  BUILD = :new

  def initialize(types, lineage)
    @types = types
    @lineage = lineage
  end

  def slots
    filled =
      @types.flat_map do |type|
        calls(type).flat_map { filling(it) }.filter_map { |slot, value| place(type, value)&.then { [slot, it] } }
      end
    filled.group_by(&:first).values.map { it.map(&:last) }
  end

  def wraps
    @types.flat_map do |type|
      handing = calls(type).select { sole(it).is_a?(Prism::SelfNode) }
      handing.flat_map { wrappers(type, it) }.map { [type.name, it] }
    end
  end

  def decorators = @_decorators ||= @types.select { decorator?(it) }.map(&:name).uniq

  private

  def calls(type) = Hashira::Smells::Scope.new(type.node).sweep.grep(Prism::CallNode)

  def place(type, node) = @lineage.resolve(type.name, Hashira::Analysis::Syntax.new(node).segments)

  def filling(call)
    given = Array(call.arguments&.arguments)
    return [[call.name.to_s.delete_suffix("="), given.first]] if call.attribute_write?
    return [] unless SLOTS.include?(call.name)
    given.grep(Prism::SymbolNode).map { Hashira::Analysis::Syntax.new(it).text }.product([defaulted(given)])
  end

  def defaulted(given)
    pairs = given.grep(Prism::KeywordHashNode).flat_map(&:elements).grep(Prism::AssocNode)
    pairs.find { it.key.is_a?(Prism::SymbolNode) && it.key.unescaped == DEFAULT }&.value
  end

  def wrappers(type, call)
    return [place(type, call.receiver) || decorators].flatten if call.name == BUILD
    folds?(call) ? decorators : []
  end

  def folds?(call) = FOLDS.include?(call.name) && Hashira::Smells::Scope.new(call).inside.any? { built?(it) }

  def built?(node) = node.is_a?(Prism::CallNode) && node.name == BUILD && sole(node)

  def sole(call) = (call.arguments.arguments.first if call.arguments&.arguments&.one?)

  def decorator?(type)
    found = @lineage.definitions(type)
    start = found.find { it.name == :initialize } or return false
    held = held(start)
    sent = found.flat_map { Hashira::Smells::Scope.new(it).inside.grep(Prism::CallNode) }.select { aimed?(it, held) }
    found.map(&:name).intersect?(sent.map(&:name))
  end

  def held(start)
    given = Hashira::Smells::Parameters.new(start).names.then { it.one? ? it : [] }.map(&:to_s)
    stored = Hashira::Smells::Scope.new(start).inside.grep(Prism::InstanceVariableWriteNode)
    stored.select { given.include?(it.value.slice) }.map { it.name.to_s }
  end

  def aimed?(call, held) = held.include?(call.receiver&.slice)
end
