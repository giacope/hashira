# frozen_string_literal: true

require "prism"

class Hashira::Constraints::NoEval < Hashira::Constraints::Tripwire
  FACT = :no_eval

  EDITION = "1.0.0"

  WEAVERS = %i[eval instance_eval class_eval module_eval instance_exec class_exec module_exec binding].freeze

  private

  def trips?(node) = named?(node, WEAVERS)
end
