# frozen_string_literal: true

require "prism"

class Hashira::Smells::Concerns
  LEVEL = "::#{Hashira::Analysis::TypeWalk::CLASS_LEVEL}".freeze

  CONCERN = %w[ActiveSupport Concern].freeze

  DSL = %i[included class_methods].freeze

  EXTEND = :extend

  def initialize(sketches)
    @sketches = sketches
  end

  def settled = @sketches.map { loose?(it) ? it.with(handed: false) : it }

  private

  def loose?(sketch)
    name = sketch.name
    name.end_with?(LEVEL) && !names.include?(name.delete_suffix(LEVEL))
  end

  def names = @_names ||= @sketches.select { concern?(it) }.to_set(&:name)

  def concern?(sketch) = Hashira::Analysis::Syntax.new(sketch.node).statements.any? { hands?(it) }

  def hands?(node)
    case node
    when Prism::CallNode then (DSL.include?(node.name) && node.block) || concerned?(node)
    when Prism::DefNode then node.name == :included && sent(node).include?(EXTEND)
    else false
    end
  end

  def concerned?(call)
    return false unless Hashira::Analysis::Syntax.new(call).macro?([EXTEND])
    segments = Hashira::Analysis::Syntax.new(call.arguments.arguments.first).segments
    segments == CONCERN || segments.last == LEVEL.delete_prefix("::")
  end

  def sent(definition) = Hashira::Smells::Scope.new(definition).inside.grep(Prism::CallNode).map(&:name)
end
