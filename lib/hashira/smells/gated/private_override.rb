# frozen_string_literal: true

require "prism"
require_relative "rule"

class Hashira::Smells::Gated::PrivateOverride < Hashira::Smells::Gated::Rule
  REQUIRES = %i[no_define_method no_method_missing].freeze

  HOOKS = %i[initialize initialize_copy respond_to_missing?].freeze

  private

  def subjects(type) = sealed(type, HOOKS)

  def entry(type, method)
    open = family.ancestral(type, method.node.name).select(&:public?)
    about(method, open, open.map(&:site), section: method.section) unless open.empty?
  end
end
