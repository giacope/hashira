# frozen_string_literal: true

require_relative "fail_on"

module Hashira::CLI::Needs
  DIAGRAMS = %i[dot mermaid].freeze

  module_function

  def check(options)
    skip = options.skip
    drawing(options.mode, skip)
    gate(options.fail_on, skip)
  end

  def drawing(mode, skip)
    return unless DIAGRAMS.include?(mode) && skip.include?(:coupling)
    raise(Hashira::Error, "--format #{mode} draws the coupling graph, but --skip coupling drops it")
  end

  def gate(fail_on, skip)
    blind = fail_on.find { skip.include?(owner(it)) }
    return unless blind
    raise(Hashira::Error, "--fail-on #{blind} needs the #{owner(blind)} analyzer, but --skip drops it")
  end

  def owner(kind) = Hashira::CLI::FailOn.owner(kind)
end
