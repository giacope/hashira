# frozen_string_literal: true

module Hashira::CLI::Format
  CHOICES = %w[text json dot mermaid].freeze

  module_function

  def parse(value)
    return if value.empty?
    return value.to_sym if CHOICES.include?(value)
    raise(Hashira::Error.unknown("--format", value, CHOICES))
  end
end
