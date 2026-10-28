# frozen_string_literal: true

class Hashira::Config::Reserve
  STRICT = %w[stateful_mixin].freeze

  private_constant :STRICT

  def initialize(kinds, strict:)
    @kinds = kinds
    @strict = strict
  end

  def held?(kind) = @kinds.include?(kind) || (!@strict && STRICT.include?(kind))

  def strict? = @strict

  def naming(named) = Hashira::Config::Reserve.new(@kinds - named, strict: @strict)

  def tightened = Hashira::Config::Reserve.new(@kinds, strict: true)
end
