# frozen_string_literal: true

require_relative "fail_on"

class Hashira::CLI::Needs
  DIAGRAMS = %i[dot mermaid].freeze

  def initialize(parsed, mode, checks = Hashira::Checks.new)
    @parsed = parsed
    @mode = mode
    @checks = checks
  end

  def check
    drawing
    gate("--fail-on", named)
    gate("--kind", kinds)
    shaping
  end

  private

  def kinds = @parsed.given("--kind")

  def skipped = @parsed.given("--skip")

  def named = Hashira::CLI::FailOn.new(@parsed.given("--fail-on")).named

  def shaping
    compacting if @parsed.given("--compact")
    focusing("--only") unless @parsed.given("--only").empty?
    sorting unless kinds.empty?
  end

  def sorting
    focusing("--kind")
    unheard = (named - kinds).first
    raise(Hashira::Error, "--fail-on #{unheard} can never fire, since --kind leaves it out") if unheard
  end

  def focusing(flag)
    raise(Hashira::Error, "#{flag} narrows the findings, but --update-baseline records them all") if @mode == :update
    return unless DIAGRAMS.include?(@mode)
    raise(Hashira::Error, "--format #{@mode} draws the coupling graph, which #{flag} cannot narrow")
  end

  def compacting
    raise(Hashira::Error, "--compact shapes JSON, but this run emits #{@mode}") unless @mode == :json
  end

  def drawing
    return unless DIAGRAMS.include?(@mode) && skipped.include?(:coupling)
    raise(Hashira::Error, "--format #{@mode} draws the coupling graph, but --skip coupling drops it")
  end

  def gate(flag, kinds)
    blind = kinds.find { skipped.include?(owner(it)) }
    return unless blind
    raise(Hashira::Error, "#{flag} #{blind} needs the #{owner(blind)} analyzer, but --skip drops it")
  end

  def owner(kind) = @checks.owner(kind)
end
