# frozen_string_literal: true

class Hashira::CI::Improvement
  def initialize(label, io: $stdout)
    @label = label
    @io = io
  end

  def print(removed)
    return if removed.empty?
    @io.puts("#{@label} (improvement!): #{removed.join(", ")}")
    @io.puts("Lock it in: re-run this command with --update-baseline")
  end
end
