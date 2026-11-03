# frozen_string_literal: true

require "digest"

class Hashira::Duplication::Shape
  DIGEST_LENGTH = 12

  def initialize(types, muted)
    @types = types
    @muted = muted
  end

  def to_a = @types

  def to_h = @types.tally

  def mass = @types.size - @muted

  def digest = Digest::SHA256.hexdigest(@types.join(",")).slice(0, DIGEST_LENGTH)
end
