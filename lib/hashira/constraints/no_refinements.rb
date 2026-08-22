# frozen_string_literal: true

require "prism"

class Hashira::Constraints::NoRefinements < Hashira::Constraints::Tripwire
  FACT = :no_refinements

  EDITION = "1.0.0"

  LENSES = %i[refine using].freeze

  private

  def trips?(node) = named?(node, LENSES) && !node.receiver
end
