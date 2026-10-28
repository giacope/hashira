# frozen_string_literal: true

class Hashira::CI::Update
  def initialize(ratchet, baseline)
    @ratchet = ratchet
    @baseline = baseline
  end

  def print
    @ratchet.record
  rescue SystemCallError => error
    raise(Hashira::Error, "cannot write #{@baseline} (#{error.message})")
  end

  def status = 0
end
