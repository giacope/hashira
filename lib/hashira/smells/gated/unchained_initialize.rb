# frozen_string_literal: true

require "prism"
require_relative "rule"

class Hashira::Smells::Gated::UnchainedInitialize < Hashira::Smells::Gated::Rule
  REQUIRES = %i[no_define_method no_method_missing].freeze

  CALLS_UP = [Prism::SuperNode, Prism::ForwardingSuperNode].freeze

  private

  def considers?(type) = super && type.kind == :class

  def subjects(type)
    own = type.owned.find { it.node.name == :initialize }
    own && !chained?(own) ? stranded(type, sets(own)) : []
  end

  def stranded(type, settled)
    family.ancestral(type, :initialize).reject { (sets(it) - settled).empty? }
  end

  def chained?(method)
    Hashira::Smells::Scope.inside(method.node).any? { CALLS_UP.include?(it.class) }
  end

  def sets(method)
    Hashira::Smells::Scope.inside(method.node).select { Hashira::Smells::Lineage::SETTERS.include?(it.class) }
      .map(&:name).uniq
  end

  def entry(type, parent) = about(type, [parent], sites(parent), names: stray(type, parent))

  def sites(parent) = [parent.site]

  def stray(type, parent) = sets(parent) - type.owned.flat_map { own(it) }

  def own(method) = method.node.name == :initialize ? sets(method) : []
end
