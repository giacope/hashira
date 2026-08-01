# frozen_string_literal: true

module Hashira::CLI::PackageBy
  CHOICES = %i[auto folder namespace].freeze

  module_function

  def parse(value)
    return :auto if value.empty?
    choice = value.to_sym
    return choice if CHOICES.include?(choice)
    raise(Hashira::Error.unknown("--package-by", value, CHOICES))
  end
end
