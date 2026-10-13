# frozen_string_literal: true

module Hashira
  module Suppression
    Directive =
      Data.define(:file, :line, :target, :kinds, :reason) do
        def site = "#{file}:#{line}"

        def covers?(kind, anchor) = kinds.include?(kind) && anchor == "#{file}:#{target}"

        def to_h = { "site" => site, "kinds" => kinds, "reason" => reason }
      end
  end
end
