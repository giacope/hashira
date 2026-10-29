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
    held = calls.flat_map { |set| made.fetch(local(set), []).map { [it, ivar(set)] } }
    held + calls.flat_map { tapped(type, definition, it) }
  end

  def made(type, definition, inside)
    inside.grep(Prism::LocalVariableWriteNode).to_h { [it.name, built(type, definition, it.value)] }
  end

  def tapped(type, definition, call)
    block = call.block
    return [] unless call.name == TAP && block.is_a?(Prism::BlockNode)
    built(type, definition, call.receiver).product(parameter(block.parameters)).flat_map do |target, held|
      Hashira::Analysis::NodeWalk.new(block).collect.grep(Prism::CallNode).filter_map { [target, ivar(it)] if local(it) == held }
    end
  end

  def parameter(parameters)
    case parameters
    when Prism::BlockParametersNode then Hashira::Smells::Parameters.new(parameters).names.first(1)
    when Prism::ItParametersNode then [:it]
    when Prism::NumberedParametersNode then [:_1]
    else []
    end
  end

  def local(call)
    return unless call.name == SET && literal?(call)
    receiver = call.receiver
    return :it if receiver.is_a?(Prism::ItLocalVariableReadNode)
    receiver.name if receiver.is_a?(Prism::LocalVariableReadNode)
  end

  def literal?(call) = Hashira::Analysis::Syntax::Word.new(call.arguments&.arguments&.first).word?

  def ivar(call) = Hashira::Analysis::Syntax::Word.new(call.arguments.arguments.first).to_s.to_sym

  def built(type, definition, value)
    return [] unless value.is_a?(Prism::CallNode) && BUILDERS.include?(value.name)
    maker = value.receiver
    return [type.name] if [nil, Prism::SelfNode].include?(maker&.class) && definition.receiver.is_a?(Prism::SelfNode)
    known(type, maker)
  end

  def known(type, maker)
    candidates = @lineage.candidates(type.name, Hashira::Analysis::Syntax.new(maker).segments)
    candidates.lazy.select { @lineage.known?(it) }.first(1)
  end
end
