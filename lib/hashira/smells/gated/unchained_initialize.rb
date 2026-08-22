# frozen_string_literal: true

require "prism"
require_relative "rule"

class Hashira::Smells::Gated::UnchainedInitialize < Hashira::Smells::Gated::Rule
  REQUIRES = %i[no_define_method no_method_missing].freeze

  CALLS_UP = [Prism::SuperNode, Prism::ForwardingSuperNode].freeze

  private

  def considers?(type) = type.kind == :class

  def subjects(type)
    own = type.owned.find { it.node.name == :initialize }
    own && !chained?(own) ? stranded(type) : []
  end

  def stranded(type)
    family.ancestral(type, :initialize).reject { sets(it).empty? }
  end

  def chained?(method)
    Hashira::Smells::Scope.inside(method.node).any? { CALLS_UP.include?(it.class) }
  end

  def sets(method)
    Hashira::Smells::Scope.inside(method.node).select { Hashira::Smells::Lineage::SETTERS.include?(it.class) }
      .map(&:name).uniq
  end

  def entry(type, parent) = about(type, [parent], [parent.site], names: sets(parent))
end
