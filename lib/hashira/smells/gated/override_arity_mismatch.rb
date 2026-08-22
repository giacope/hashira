# frozen_string_literal: true

require "prism"
require_relative "rule"
require_relative "shape"

class Hashira::Smells::Gated::OverrideArityMismatch < Hashira::Smells::Gated::Rule
  REQUIRES = %i[no_define_method no_method_missing].freeze

  HOOKS = %i[initialize initialize_copy].freeze

  private

  def subjects(type) = type.owned.reject { HOOKS.include?(it.node.name) }

  def entry(type, method)
    breaks = family.ancestral(type, method.node.name).reject { agrees?(method, it) }
    about(method, breaks, quotes(method, breaks)) unless breaks.empty?
  end

  def agrees?(method, parent)
    return true if opaque?(method) || opaque?(parent)
    faults(shape(method), shape(parent)).empty?
  end

  def opaque?(method) = shape(method).opaque?

  def shape(method) = Hashira::Smells::Gated::Shape.new(method.node)

  def faults(here, there)
    return ["takes fewer arguments than"] if here.narrower?(there)
    here.refuses(there).map { "rejects #{it}: unlike" } + here.imposes(there).map { "demands #{it}: unlike" }
  end

  def quotes(method, breaks) = breaks.flat_map { faulted(shape(method), it) }

  def faulted(here, parent) = faults(here, shape(parent)).map { "#{it} #{parent.subject}" }
end
