# frozen_string_literal: true

require_relative "contracts"

class Hashira::Coupling::Spoken
  include Hashira::Coupling::Contracts

  MESSAGES = Hashira::Runtime::Messages.new

  def initialize(names, heard, stems, referenced)
    @names = names
    @heard = heard
    @stems = stems
    @referenced = referenced
  end

  def called?(selector)
    HOOKS.include?(selector) || protocol?(selector) || said?(selector) ||
      @heard.include?(selector.delete_suffix("=")) || @stems.dynamic?(selector)
  end

  def named?(path) = @referenced.include?(path.join("::")) || said?(path.last) || @stems.assembled?(path)

  private

  def said?(name) = @names.include?(name) || @heard.include?(name)

  def protocol?(name) = MESSAGES.universal?(name.to_sym) || MESSAGES.value?(name.to_sym)
end
