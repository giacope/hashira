# frozen_string_literal: true

require "prism"

class Hashira::Constraints::NoConstMissing < Hashira::Constraints::Tripwire
  FACT = :no_const_missing

  EDITION = "1.0.0"

  MAKERS = %i[const_set remove_const const_get].freeze

  private

  def trips?(node) = hook?(node) || named?(node, MAKERS)

  def hook?(node) = node.is_a?(Prism::DefNode) && node.name == :const_missing
end
