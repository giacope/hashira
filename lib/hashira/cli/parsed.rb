# frozen_string_literal: true

class Hashira::CLI::Parsed
  def initialize(values)
    @values = values
  end

  def given(name) = @values.fetch(@values.keys.find { it.named?(name) })

  def mode
    case (asked = @values.flat_map { |flag, value| flag.bid(value) }.uniq(&:last))
    in [] then :text
    in [[_flag, mode]] then mode
    else raise(Hashira::Error, "conflicting options: #{asked.map(&:first).join(" and ")}")
    end
  end
end
