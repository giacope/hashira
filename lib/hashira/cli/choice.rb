# frozen_string_literal: true

module Hashira::CLI::Choice
  module_function

  def unknown(flag, value, choices)
    Hashira::Error.new("unknown #{flag} #{value.inspect} (use: #{choices.join(", ")})")
  end
end
