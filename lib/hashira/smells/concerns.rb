# frozen_string_literal: true

require "prism"

class Hashira::Smells::Concerns
  LEVEL = "::ClassMethods"

  CONCERN = %w[ActiveSupport Concern].freeze

  DSL = %i[included class_methods].freeze

  EXTEND = :extend

  def initialize(found)
    @found = found
  end

  def loose?(name) = name.end_with?(LEVEL) && !names.include?(name.delete_suffix(LEVEL))

  private

  def names = @_names ||= @found.select { |_name, node| concern?(node) }.to_set(&:first)

  def concern?(node) = Hashira::Analysis::Syntax::Body.new(node).to_a.any? { hands?(it) }

  def hands?(node)
    case node
    when Prism::CallNode then (DSL.include?(node.name) && node.block) || concerned?(node)
    when Prism::DefNode then node.name == :included && sent(node).include?(EXTEND)
    else false
    end
  end

  def concerned?(call)
    return false unless Hashira::Analysis::Syntax::Call.new(call).macro?([EXTEND])
    segments = Hashira::Analysis::Syntax.new(call.arguments.arguments.first).segments
    segments == CONCERN || segments.last == LEVEL.delete_prefix("::")
  end

  def sent(definition) = Hashira::Smells::Scope.new(definition).inside.grep(Prism::CallNode).map(&:name)
end
