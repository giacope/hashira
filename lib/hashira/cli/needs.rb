# frozen_string_literal: true

require_relative "fail_on"

module Hashira::CLI::Needs
  DIAGRAMS = %i[dot mermaid].freeze

  module_function

  def check(options)
    mode = options.mode
    skip = options.skip
    drawing(mode, skip)
    gate(options.fail_on, skip)
    shaping(mode) if options.compact
  end

  def shaping(mode)
    raise(Hashira::Error, "--compact shapes JSON, but this run emits #{mode}") unless mode == :json
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
