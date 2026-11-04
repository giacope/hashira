# frozen_string_literal: true

class Hashira::Coupling::Territory
  def initialize(entries, claims)
    @entries = entries
    @claims = claims
  end

  def owned?(path) = owned.include?(path)

  private

  def owned = @_owned ||= @entries.reject { it.to_a.empty? }.select { it.kin.claimed?(@claims) }.to_set(&:to_a)
end
