# frozen_string_literal: true

module Hashira
  module Coupling
    PLURALS = [
      [/$/, "s"], [/s$/i, "s"], [/^(ax|test)is$/i, '\1es'], [/(octop|vir)us$/i, '\1i'], [/(octop|vir)i$/i, '\1i'],
      [/(alias|status)$/i, '\1es'], [/(bu)s$/i, '\1ses'], [/(buffal|tomat)o$/i, '\1oes'], [/([ti])um$/i, '\1a'],
      [/([ti])a$/i, '\1a'], [/sis$/i, "ses"], [/(?:([^f])fe|([lr])f)$/i, '\1\2ves'], [/(hive)$/i, '\1s'],
      [/([^aeiouy]|qu)y$/i, '\1ies'], [/(x|ch|ss|sh)$/i, '\1es'], [/(matr|vert|ind)(?:ix|ex)$/i, '\1ices'],
      [/^(m|l)ouse$/i, '\1ice'], [/^(m|l)ice$/i, '\1ice'], [/^(ox)$/i, '\1en'], [/^(oxen)$/i, '\1'],
      [/(quiz)$/i, '\1zes']
    ].freeze

    SINGULARS = [
      [/s$/i, ""], [/(ss)$/i, '\1'], [/(n)ews$/i, '\1ews'], [/([ti])a$/i, '\1um'],
      [/((a)naly|(b)a|(d)iagno|(p)arenthe|(p)rogno|(s)ynop|(t)he)(sis|ses)$/i, '\1sis'],
      [/(^analy)(sis|ses)$/i, '\1sis'],
      [/([^f])ves$/i, '\1fe'], [/(hive)s$/i, '\1'], [/(tive)s$/i, '\1'], [/([lr])ves$/i, '\1f'],
      [/([^aeiouy]|qu)ies$/i, '\1y'], [/(s)eries$/i, '\1eries'], [/(m)ovies$/i, '\1ovie'], [/(x|ch|ss|sh)es$/i, '\1'],
      [/^(m|l)ice$/i, '\1ouse'], [/(bus)(es)?$/i, '\1'], [/(o)es$/i, '\1'], [/(shoe)s$/i, '\1'],
      [/(cris|test)(is|es)$/i, '\1is'], [/^(a)x[ie]s$/i, '\1xis'], [/(octop|vir)(us|i)$/i, '\1us'],
      [/(alias|status)(es)?$/i, '\1'], [/^(ox)en/i, '\1'], [/(vert|ind)ices$/i, '\1ex'], [/(matr)ices$/i, '\1ix'],
      [/(quiz)zes$/i, '\1'], [/(database)s$/i, '\1']
    ].freeze

    IRREGULARS = [
      %w[person people], %w[man men], %w[child children], %w[sex sexes], %w[move moves], %w[zombie zombies]
    ].freeze

    UNCOUNTABLES = %w[equipment information rice money species series fish sheep jeans police].freeze

    private_constant :PLURALS, :SINGULARS, :IRREGULARS, :UNCOUNTABLES

    class Inflections
      def self.of(trees) = trees.reduce(STOCK) { |table, tree| Hashira::Coupling::Declared.new(tree).onto(table) }

      def initialize(plurals, singulars, uncountables, acronyms)
        @plurals = plurals
        @singulars = singulars
        @uncountables = uncountables
        @acronyms = acronyms
      end

      def +(other) = other.under(@plurals, @singulars, @uncountables, @acronyms)

      def plural(word) = inflect(word, @plurals)

      def singular(word) = inflect(word, @singulars)

      def cased(part) = @acronyms.find { it.downcase == part } || part.capitalize

      protected

      def under(plurals, singulars, uncountables, acronyms)
        self.class.new(@plurals + plurals, @singulars + singulars, uncountables + @uncountables, acronyms + @acronyms)
      end

      private

      def inflect(word, rules)
        return word if @uncountables.any? { word.downcase.match?(/\b#{Regexp.escape(it)}\z/) }
        rule, replacement = rules.find { |pattern, _| word.match?(pattern) }
        rule ? word.sub(rule, replacement) : word
      end
    end

    STOCK =
      IRREGULARS.reduce(Inflections.new(PLURALS.reverse, SINGULARS.reverse, UNCOUNTABLES, [])) do |table, pair|
        table + Hashira::Coupling::Irregular.new(*pair).to_table
      end

    private_constant :STOCK
  end
end
