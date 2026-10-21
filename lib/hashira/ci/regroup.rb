# frozen_string_literal: true

class Hashira::CI::Regroup
  PAIRED = " ⇄ "

  def initialize(gone, current)
    @gone = gone
    @current = current
  end

  def from = @_from ||= @gone.select { |key| targets(key).any? { @current.key?(it) } }

  def into = from.flat_map { targets(it) }

  private

  def targets(key)
    kind, identity = key.split(":", 2)
    case kind
    when "repeated_call" then ["#{kind}:#{identity.split(/[#.]/, 2).first}"]
    when "bidirectional_association" then identity.split(PAIRED).map { "#{kind}:#{it}" }
    else []
    end
  end
end
