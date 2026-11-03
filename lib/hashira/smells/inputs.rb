# frozen_string_literal: true

require "prism"

class Hashira::Smells::Inputs
  HIDDEN = %i[private protected].freeze

  OPTIONAL = [Prism::OptionalParameterNode, Prism::OptionalKeywordParameterNode].freeze

  private_constant :HIDDEN, :OPTIONAL

  def initialize(subject, rules)
    @subject = subject
    @rules = rules
  end

  def parameter?(name) = @subject.parameters.include?(name)

  def handed?(name) = HIDDEN.include?(@subject.section) || defaulted.include?(name)

  def optional?(node) = node.is_a?(Prism::LocalVariableReadNode) && defaulted.include?(node.name)

  def strict? = @rules.strict?

  private

  def defaulted = @_defaulted ||= strict? ? nils : []

  def nils
    Hashira::Smells::Parameters.new(@subject.node).parts.filter_map do
      it.name if OPTIONAL.include?(it.class) && it.value.is_a?(Prism::NilNode)
    end
  end
end
