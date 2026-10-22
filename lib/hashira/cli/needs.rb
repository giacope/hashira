# frozen_string_literal: true

require_relative "fail_on"

class Hashira::CLI::Needs
  DIAGRAMS = %i[dot mermaid].freeze

  def initialize(options)
    @options = options
  end

  def check
    drawing
    gate("--fail-on", @options.fail_on - [Hashira::CLI::FailOn::EVERY])
    gate("--kind", @options.kinds)
    shaping
  end

  private

  def mode = @options.mode

  def shaping
    compacting if @options.compact
    focusing("--only") unless @options.only.empty?
    sorting unless @options.kinds.empty?
  end

  def sorting
    focusing("--kind")
    unheard = (@options.fail_on - [Hashira::CLI::FailOn::EVERY] - @options.kinds).first
    raise(Hashira::Error, "--fail-on #{unheard} can never fire, since --kind leaves it out") if unheard
  end

  def focusing(flag)
    raise(Hashira::Error, "#{flag} narrows the findings, but --update-baseline records them all") if mode == :update
    return unless DIAGRAMS.include?(mode)
    raise(Hashira::Error, "--format #{mode} draws the coupling graph, which #{flag} cannot narrow")
  end

  def compacting
    raise(Hashira::Error, "--compact shapes JSON, but this run emits #{mode}") unless mode == :json
  end

  def drawing
    return unless DIAGRAMS.include?(mode) && @options.skip.include?(:coupling)
    raise(Hashira::Error, "--format #{mode} draws the coupling graph, but --skip coupling drops it")
  end

  def gate(flag, kinds)
    blind = kinds.find { @options.skip.include?(owner(it)) }
    return unless blind
    raise(Hashira::Error, "#{flag} #{blind} needs the #{owner(blind)} analyzer, but --skip drops it")
  end

  def owner(kind) = Hashira::CLI::FailOn::OWNERS.fetch(kind)
end
