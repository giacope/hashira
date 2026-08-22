# frozen_string_literal: true

require "prism"
require_relative "rule"

class Hashira::Smells::Gated::MixinCollision < Hashira::Smells::Gated::Rule
  REQUIRES = %i[no_define_method no_eval].freeze

  private

  def considers?(type) = type.kind == :class

  def subjects(type)
    settled = type.owned.map { it.node.name }
    shared(type).reject { settled.include?(it.first.node.name) }
  end

  def shared(type)
    claims(type).values.select { it.size > 1 }
  end

  def claims(type)
    mixed(type).each_with_object({}) { |method, found| (found[method.node.name] ||= []) << method }
  end

  def mixed(type) = family.mixins(type).flat_map { spoken(it) }

  def spoken(mixin) = mixin.flat_map(&:owned).uniq { it.node.name }

  def entry(type, claimants) = about(type, claimants, sites(claimants), names: disputed(claimants))

  def sites(claimants) = claimants.map(&:site)

  def disputed(claimants) = [claimants.first.node.name]
end
