# frozen_string_literal: true

class Hashira::Coupling::Irregular
  def initialize(one, many)
    @one = one
    @many = many
  end

  def to_table
    Hashira::Coupling::Inflections.new(
      [rule(@one, @many), rule(@many, @many)], [rule(@many, @one), rule(@one, @one)], [], []
    )
  end

  private

  def rule(from, to) = [/(#{from[0]})#{from[1..]}$/i, "\\1#{to[1..]}"]
end
