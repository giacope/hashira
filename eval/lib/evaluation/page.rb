# frozen_string_literal: true

class Evaluation::Page
  def initialize(text)
    @text = text
  end

  def print(io) = io.puts(@text)

  def status = 0
end
