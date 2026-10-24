# frozen_string_literal: true

require "prism"

class Hashira::Smells::Plantings
  BUILDERS = %i[new allocate].freeze

  SET = :instance_variable_set

  TAP = :tap

  def initialize(types, lineage)
    @types = types
    @lineage = lineage
  end

  def of(name) = (@_found ||= found).fetch(name, [])

  private

  def found
    planted = @types.flat_map { |type| @lineage.sweep(type).grep(Prism::DefNode).flat_map { planted(type, it) } }
    planted.group_by(&:first).transform_values { |pairs| pairs.map(&:last).uniq }
  end

  def planted(type, definition)
    inside = Hashira::Smells::Scope.new(definition).inside
    made = made(type, definition, inside)
    calls = inside.grep(Prism::CallNode)
    calls.filter_map { |set| [made[local(set)], ivar(set)] if made.key?(local(set)) } +
      calls.flat_map { tapped(type, definition, it) }
  end

  def made(type, definition, inside)
    inside.grep(Prism::LocalVariableWriteNode).to_h { [it.name, built(type, definition, it.value)] }.compact
  end

  def tapped(type, definition, call)
    target = built(type, definition, call.receiver) if call.name == TAP && call.block.is_a?(Prism::BlockNode)
    held = parameter(call.block.parameters) if target
    return [] unless held
    Hashira::Analysis::NodeWalk.new(call.block).collect.grep(Prism::CallNode).filter_map { [target, ivar(it)] if local(it) == held }
  end

  def parameter(parameters)
    case parameters
    when Prism::BlockParametersNode then Array(parameters.parameters&.requireds).first&.name
    when Prism::ItParametersNode then :it
    when Prism::NumberedParametersNode then :_1
    end
  end

  def local(call)
    return unless call.name == SET && literal?(call)
    receiver = call.receiver
    return :it if receiver.is_a?(Prism::ItLocalVariableReadNode)
    receiver.name if receiver.is_a?(Prism::LocalVariableReadNode)
  end

  def literal?(call) = Hashira::Analysis::Syntax.new(call.arguments&.arguments&.first).word?

  def ivar(call) = Hashira::Analysis::Syntax.new(call.arguments.arguments.first).text.to_sym

  def built(type, definition, value)
    return unless value.is_a?(Prism::CallNode) && BUILDERS.include?(value.name)
    maker = value.receiver
    return type.name if [nil, Prism::SelfNode].include?(maker&.class) && definition.receiver.is_a?(Prism::SelfNode)
    @lineage.candidates(type.name, Hashira::Analysis::Syntax.new(maker).segments).find { @lineage.known?(it) }
  end
end
