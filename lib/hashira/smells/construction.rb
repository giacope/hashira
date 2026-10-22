# frozen_string_literal: true

require "prism"

class Hashira::Smells::Construction
  START = :initialize

  SUPERS = [Prism::SuperNode, Prism::ForwardingSuperNode].freeze

  def initialize(kin)
    @kin = kin
  end

  def reached = @_reached ||= Set.new.tap { visit(START, 0, it) }.to_set(&:first) << START

  private

  def visit(name, from, seen)
    slot = (from...@kin.size).find { table(it).key?(name) }
    return unless slot && seen.add?([name, slot])
    found = table(slot).fetch(name)
    called(found).each { visit(it, 0, seen) }
    visit(name, slot + 1, seen) if found.any? { SUPERS.include?(it.class) }
  end

  def called(found) = found.grep(Prism::CallNode).select { inward?(it.receiver) }.map(&:name)

  def inward?(receiver) = receiver.nil? || receiver.is_a?(Prism::SelfNode)

  def table(slot)
    (@_tables ||= {})[slot] ||= Hashira::Smells::Scope.new(@kin[slot].node).sweep.grep(Prism::DefNode).reject(&:receiver)
      .to_h { [it.name, Hashira::Smells::Scope.new(it).inside] }
  end
end
