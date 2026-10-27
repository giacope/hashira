# frozen_string_literal: true

module Hashira
  module Config
    Reserve =
      Data.define(:kinds, :strict) do
        def held?(kind) = kinds.include?(kind) || (!strict && Rules::STRICT.include?(kind))

        def naming(named) = with(kinds: kinds - named)
      end
  end
end
