# frozen_string_literal: true

require "prism"

class Hashira::Smells::Memo
  def initialize(branch)
    @branch = branch
  end

  def fills?(held)
    found = Array(@branch.statements&.body)
    !@branch.subsequent && found.one? && Hashira::Smells::Course::WRITES.include?(found.first.class) &&
      held.map(&:slice).include?(found.first.name.to_s)
  end
end
