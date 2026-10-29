# frozen_string_literal: true

class Hashira::Report::Text
  def initialize(sections)
    @sections = sections
  end

  def print = @sections.each(&:print)

  def status = 0
end
