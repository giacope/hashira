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
    shaping(options, mode)
  end

  def shaping(options, mode)
    compacting(mode) if options.compact
    focusing(mode) unless options.only.empty?
  end

  def focusing(mode)
    raise(Hashira::Error, "--only narrows the findings, but --update-baseline records them all") if mode == :update
    return unless DIAGRAMS.include?(mode)
    raise(Hashira::Error, "--format #{mode} draws the coupling graph, which --only cannot narrow")
  end

  def compacting(mode)
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
