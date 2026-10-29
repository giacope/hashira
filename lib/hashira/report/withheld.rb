# frozen_string_literal: true

class Hashira::Report::Withheld
  def initialize(rest)
    @rest = rest
  end

  def to_s = "  … and #{rest} more — raise the cap with --top, or read them all with --json"

  private

  attr_reader :rest
end
