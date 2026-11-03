# frozen_string_literal: true

require "prism"
require_relative "reads"

class Hashira::Smells::TypeTests
  include Hashira::Smells::Reads

  LOOKUPS = %i[[] fetch].freeze

  CASES = [Prism::CaseNode, Prism::CaseMatchNode].freeze

  SHAPED = [Prism::ArrayPatternNode, Prism::FindPatternNode, Prism::HashPatternNode].freeze

  def initialize(body, names)
    @body = body
    @names = names
  end

  def of(&)
    written = (probes(&) + arms(&)).map { Hashira::Analysis::Syntax.new(it) }.reject { it.segments.empty? }
    written.map { [it.segments, it.rooted?] } + lookups(&).map { [it, false] }
  end

  private

  def calls = @_calls ||= @body.grep(Prism::CallNode)

  def probes(&) = calls.select { tests?(it) && local?(it.receiver, &) }.flat_map { keys(it) }

  def tests?(call) = Hashira::Analysis::Syntax::Message.new(call).type_test?

  def arms(&)
    switches = @body.select { CASES.include?(it.class) && local?(it.predicate, &) }
    switches.flat_map(&:conditions).flat_map do |arm|
      next arm.conditions unless arm.is_a?(Prism::InNode)
      pattern = arm.pattern
      [SHAPED.include?(pattern.class) ? pattern.constant : pattern]
    end
  end

  def lookups(&)
    calls.select { |call| LOOKUPS.include?(call.name) && keys(call).any? { sorts?(it, &) } }
      .flat_map { @names.keys(Hashira::Analysis::Syntax.new(it.receiver).segments) }
  end

  def sorts?(argument, &) = argument.is_a?(Prism::CallNode) && argument.name == :class && local?(argument.receiver, &)
end
