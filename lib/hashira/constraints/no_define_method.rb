# frozen_string_literal: true

require "prism"

class Hashira::Constraints::NoDefineMethod < Hashira::Constraints::Tripwire
  FACT = :no_define_method

  EDITION = "1.0.0"

  MAKERS = %i[define_method define_singleton_method].freeze

  private

  def trips?(node) = named?(node, MAKERS)
end
