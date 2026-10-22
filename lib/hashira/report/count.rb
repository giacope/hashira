# frozen_string_literal: true

Hashira::Report::Count =
  Data.define(:number, :noun) do
    def to_s = "#{number} #{number == 1 ? noun : "#{noun}s"}"
  end

Hashira::Report::Withheld =
  Data.define(:rest) do
    def to_s = "  … and #{rest} more — raise the cap with --top, or read them all with --json"
  end
