# frozen_string_literal: true

require "prism"
require_relative "reads"

class Hashira::Smells::TypeTests
  include Hashira::Smells::Reads

  CHECKS = %i[is_a? kind_of? instance_of?].freeze

  LOOKUPS = %i[[] fetch].freeze

  def initialize(body, ownership)
    @body = body
    @ownership = ownership
  end

  def of(&)
    (probes(&) + arms(&)).map { Hashira::Analysis::Syntax.segments(it) }.reject(&:empty?) + lookups(&)
  end

  private

  def calls = @_calls ||= @body.grep(Prism::CallNode)

  def probes(&) = calls.select { CHECKS.include?(it.name) && local?(it.receiver, &) }.filter_map { key(it) }

  def arms(&)
    @body.grep(Prism::CaseNode).select { local?(it.predicate, &) }.flat_map(&:conditions).flat_map(&:conditions)
  end

  def lookups(&)
    calls.select { LOOKUPS.include?(it.name) && sorts?(key(it), &) }.flat_map { table(it.receiver) }
  end

  def table(receiver) = @ownership.keys(Hashira::Analysis::Syntax.segments(receiver))

  def sorts?(argument, &) = argument.is_a?(Prism::CallNode) && argument.name == :class && local?(argument.receiver, &)
end
