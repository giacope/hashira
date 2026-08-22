# frozen_string_literal: true

module Hashira
  module Constraints
    Declaration =
      Data.define(:name, :scope) do
        def fact = Vocabulary.find(name)

        def covers?(path) = scope == "." || path.start_with?("#{scope}/")

        def identity = "#{name}@#{fact::EDITION}:#{scope}"

        def within(trees) = trees.select { |path, _tree| covers?(path) }

        def contradiction(trees) = fact.new(within(trees)).contradiction
      end
  end
end
