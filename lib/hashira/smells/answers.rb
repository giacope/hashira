# frozen_string_literal: true

require "prism"

class Hashira::Smells::Answers
  CONSTANTS = [Prism::ConstantReadNode, Prism::ConstantPathNode].freeze

  private_constant :CONSTANTS

  def initialize(speech, locals, holders, inputs)
    @speech = speech
    @locals = locals
    @holders = holders
    @inputs = inputs
  end

  def answered?(call)
    receiver = call.receiver
    return @speech.own?(call.name) if receiver.nil? || receiver.is_a?(Prism::SelfNode)
    return @holders.answers?(receiver) if CONSTANTS.include?(receiver.class)
    reached?(call)
  end

  private

  def reached?(call)
    receiver = call.receiver
    case receiver
    when Prism::LocalVariableReadNode then @locals.answered?(receiver.name, call.name)
    when Prism::InstanceVariableReadNode then @inputs.strict? && @holders.sprung(call).any?
    when Prism::CallNode then @inputs.strict? && (@holders.sprung(call).any? || spoken?(receiver, call.name))
    else false
    end
  end

  def spoken?(receiver, message) = @speech.spoken?(@holders.of(receiver), message)
end
