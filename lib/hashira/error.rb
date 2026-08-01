# frozen_string_literal: true

class Hashira::Error < StandardError
  def self.unknown(flag, value, choices)
    new("unknown #{flag} #{value.inspect} (use: #{choices.join(", ")})")
  end
end
