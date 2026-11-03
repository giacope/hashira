# frozen_string_literal: true

require "prism"

class Hashira::Smells::Inputs
  HIDDEN = %i[private protected].freeze

  private_constant :HIDDEN

  def initialize(subject, rules)
    @subject = subject
    @rules = rules
  end

  def parameter?(name) = parameters.names.include?(name)

  def handed?(name) = @subject.standing.in?(HIDDEN) || defaulted.include?(name)

  def optional?(node) = node.is_a?(Prism::LocalVariableReadNode) && defaulted.include?(node.name)

  def strict? = @rules.strict?

  private

  def parameters = @subject.accept(Hashira::Smells::Parameters)

  def defaulted = @_defaulted ||= strict? ? parameters.nils : []
end
