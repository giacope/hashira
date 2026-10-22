# frozen_string_literal: true

class Hashira::CLI::Choice
  def initialize(flag, choices, blank = nil)
    @flag = flag
    @choices = choices
    @blank = blank
  end

  def parse(value)
    return @blank if value.empty?
    chosen = value.to_sym
    return chosen if @choices.include?(chosen)
    raise(unknown(value))
  end

  def unknown(value) = Hashira::Error.new("unknown #{@flag} #{value.inspect} (use: #{@choices.join(", ")})")
end
