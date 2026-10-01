# frozen_string_literal: true

require_relative "fail_on"

module Hashira::CLI::Needs
  DIAGRAMS = %i[dot mermaid].freeze

  module_function

  def check(options)
    mode = options.mode
    drawing(mode, options.skip)
    gates(options)
    shaping(options, mode)
  end

  def gates(options)
    skip = options.skip
    gate("--fail-on", options.fail_on, skip)
    gate("--kind", options.kinds, skip)
  end

  def shaping(options, mode)
    compacting(mode) if options.compact
    focusing("--only", mode) unless options.only.empty?
    sorting(options, mode) unless options.kinds.empty?
  end

  def sorting(options, mode)
    focusing("--kind", mode)
    unheard = (options.fail_on - options.kinds).first
    raise(Hashira::Error, "--fail-on #{unheard} can never fire, since --kind leaves it out") if unheard
  end

  def focusing(flag, mode)
    raise(Hashira::Error, "#{flag} narrows the findings, but --update-baseline records them all") if mode == :update
    return unless DIAGRAMS.include?(mode)
    raise(Hashira::Error, "--format #{mode} draws the coupling graph, which #{flag} cannot narrow")
  end

  def compacting(mode)
    raise(Hashira::Error, "--compact shapes JSON, but this run emits #{mode}") unless mode == :json
  end

  def drawing(mode, skip)
    return unless DIAGRAMS.include?(mode) && skip.include?(:coupling)
    raise(Hashira::Error, "--format #{mode} draws the coupling graph, but --skip coupling drops it")
  end

  def gate(flag, kinds, skip)
    blind = kinds.find { skip.include?(owner(it)) }
    return unless blind
    raise(Hashira::Error, "#{flag} #{blind} needs the #{owner(blind)} analyzer, but --skip drops it")
  end

  def owner(kind) = Hashira::CLI::FailOn.owner(kind)
end
