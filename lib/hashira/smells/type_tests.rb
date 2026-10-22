# frozen_string_literal: true

require "prism"
require_relative "reads"

class Hashira::Smells::TypeTests
  include Hashira::Smells::Reads

  CHECKS = %i[is_a? kind_of? instance_of?].freeze

  LOOKUPS = %i[[] fetch].freeze

  CASES = [Prism::CaseNode, Prism::CaseMatchNode].freeze

  SHAPED = [Prism::ArrayPatternNode, Prism::FindPatternNode, Prism::HashPatternNode].freeze

  def initialize(body, ownership)
    @body = body
    @ownership = ownership
  end

  def of(&)
    (probes(&) + arms(&)).map { Hashira::Analysis::Syntax.new(it).segments }.reject(&:empty?) + lookups(&)
  end

  private

  def calls = @_calls ||= @body.grep(Prism::CallNode)

  def probes(&) = calls.select { CHECKS.include?(it.name) && local?(it.receiver, &) }.filter_map { key(it) }

  def arms(&)
    switches = @body.select { CASES.include?(it.class) && local?(it.predicate, &) }
    switches.flat_map(&:conditions).flat_map do |arm|
      next arm.conditions unless arm.is_a?(Prism::InNode)
      pattern = arm.pattern
      [SHAPED.include?(pattern.class) ? pattern.constant : pattern]
    end
  end

  def lookups(&)
    calls.select { LOOKUPS.include?(it.name) && sorts?(key(it), &) }.flat_map { table(it.receiver) }
  end

  def table(receiver) = @ownership.keys(Hashira::Analysis::Syntax.new(receiver).segments)

  def sorts?(argument, &) = argument.is_a?(Prism::CallNode) && argument.name == :class && local?(argument.receiver, &)
end
