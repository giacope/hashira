# frozen_string_literal: true

require_relative "no_define_method"
require_relative "no_const_missing"
require_relative "no_eval"
require_relative "no_method_missing"
require_relative "no_refinements"

module Hashira::Constraints::Vocabulary
  FACTS = Hashira::Constraints::Tripwire.subclasses.sort_by { it::FACT }.freeze

  INDEX = FACTS.to_h { [it::FACT, it] }.freeze

  module_function

  def names = INDEX.keys

  def find(name) = INDEX[name]

  def known?(name) = INDEX.key?(name)

  def listed = names.join(", ")
end
