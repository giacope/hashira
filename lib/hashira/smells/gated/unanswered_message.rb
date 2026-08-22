# frozen_string_literal: true

require "prism"
require_relative "rule"

class Hashira::Smells::Gated::UnansweredMessage < Hashira::Smells::Gated::Rule
  REQUIRES = %i[no_define_method no_eval no_method_missing no_refinements].freeze

  RUBY = (Object.instance_methods + Object.private_instance_methods).to_set.freeze

  MACROS = %i[
    attr attr_reader attr_writer attr_accessor include extend prepend private public protected
    module_function alias_method require require_relative raise freeze private_constant public_constant
  ].to_set.freeze

  private

  def considers?(type) = super && type.kind == :class && plain?(type)

  def plain?(type) = family.kin(type).all? { tame?(it) }

  def tame?(kin)
    Hashira::Analysis::Syntax.statements(kin.node).compact.grep(Prism::CallNode).all? { MACROS.include?(it.name) }
  end

  def subjects(type) = type.owned.reject(&:singleton?).flat_map { strays(type, it) }

  def strays(type, method)
    calls(method).reject { known?(type, it.name) }.map { [method, it] }
  end

  def calls(method)
    Hashira::Smells::Scope.inside(method.node).grep(Prism::CallNode).select { inward?(it) }
  end

  def inward?(node) = selfish?(node.receiver) && !passing?(node.block)

  def passing?(block) = block.is_a?(Prism::BlockArgumentNode)

  def known?(type, name) = RUBY.include?(name) || family.answers?(type, name)

  def entry(_type, pair)
    method, call = pair
    about(method, [method], [where(method, call)], names: [call.name])
  end

  def where(method, call) = "#{method.file}:#{call.location.start_line}"
end
