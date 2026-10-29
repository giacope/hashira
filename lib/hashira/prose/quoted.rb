# frozen_string_literal: true

class Hashira::Prose::Quoted
  def initialize(names)
    @names = names
  end

  def to_s = @names.map { "'#{it}'" }.join(", ")
end
