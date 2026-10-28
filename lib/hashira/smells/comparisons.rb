# frozen_string_literal: true

class Hashira::Smells::Comparisons
  NAMES = %i[<=> == eql? === equal? coerce].freeze

  private_constant :NAMES

  def initialize(names = NAMES)
    @names = names
  end

  def include?(name) = @names.include?(name)
end
