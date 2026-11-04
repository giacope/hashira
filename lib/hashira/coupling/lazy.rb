# frozen_string_literal: true

class Hashira::Coupling::Lazy
  def initialize(&made)
    @made = made
  end

  def call = @_call ||= @made.call
end
