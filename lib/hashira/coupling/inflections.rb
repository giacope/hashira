# frozen_string_literal: true

module Hashira
  module Coupling
    Inflections =
      Data.define(:plurals, :singulars, :uncountables, :acronyms) do
        def self.of(tree)
          stock = STOCK.irregulars(Inflection::IRREGULARS)
          tree ? Declared.new(tree).onto(stock) : stock
        end

        def irregulars(pairs) = pairs.reduce(self) { |table, (one, many)| table.irregular(one, many) }

        def irregular(one, many)
          with(
            plurals: [rule(one, many), rule(many, many)] + plurals,
            singulars: [rule(many, one), rule(one, one)] + singulars
          )
        end

        def rule(from, to) = [/(#{from[0]})#{from[1..]}$/i, "\\1#{to[1..]}"]
      end

    STOCK = Inflections.new(
      plurals: Inflection::PLURALS.reverse, singulars: Inflection::SINGULARS.reverse,
      uncountables: Inflection::UNCOUNTABLES, acronyms: []
    )
  end
end
