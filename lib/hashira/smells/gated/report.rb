# frozen_string_literal: true

require_relative "../kind"
require_relative "family"
require_relative "rule"
require_relative "abstract_stub_gap"
require_relative "dead_method"
require_relative "hierarchy_dispatch"
require_relative "mixin_collision"
require_relative "override_arity_mismatch"
require_relative "private_override"
require_relative "unanswered_message"
require_relative "unchained_initialize"
require_relative "unreachable_rescue"
require_relative "registry_gap"

class Hashira::Smells::Gated::Report
  RULES = Hashira::Smells::Gated::Rule.subclasses.sort_by(&:name).freeze

  KINDS = RULES.map { Hashira::Smells::Kind.new(it).to_s }.sort.freeze

  def initialize(types, trees, declarations)
    @types = types
    @trees = trees
    @declarations = declarations
  end

  def findings = RULES.flat_map { granted?(it) ? it.new(family, @trees).list : [] }

  private

  def family = @_family ||= Hashira::Smells::Gated::Family.new(@types)

  def granted?(rule) = @declarations.grants?(rule::REQUIRES, @trees.keys)
end
