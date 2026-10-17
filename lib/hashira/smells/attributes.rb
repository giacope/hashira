# frozen_string_literal: true

module Hashira::Smells::Attributes
  module_function

  def ivars(nodes, kinds) = nodes.select { kinds.include?(it.class) }.map(&:name)
end
