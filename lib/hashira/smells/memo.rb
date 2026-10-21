# frozen_string_literal: true

require "prism"

module Hashira::Smells::Memo
  module_function

  def fills?(branch, held)
    found = Array(branch.statements&.body)
    !branch.subsequent && found.one? && Hashira::Smells::Course::WRITES.include?(found.first.class) &&
      held.map(&:slice).include?(found.first.name.to_s)
  end
end
