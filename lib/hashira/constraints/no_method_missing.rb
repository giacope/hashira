# frozen_string_literal: true

require "prism"

class Hashira::Constraints::NoMethodMissing < Hashira::Constraints::Tripwire
  FACT = :no_method_missing

  EDITION = "1.0.0"

  HOOKS = %i[method_missing respond_to_missing?].freeze

  private

  def trips?(node) = node.is_a?(Prism::DefNode) && HOOKS.include?(node.name)
end
