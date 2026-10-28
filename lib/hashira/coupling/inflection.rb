# frozen_string_literal: true

class Hashira::Coupling::Inflection
  def initialize(table)
    @table = table
  end

  def plural(word) = inflect(word, @table.plurals)

  def singular(word) = inflect(word, @table.singulars)

  def camelize(word) = word.split("/").map { |part| part.split("_").map { cased(it) }.join }.join("::")

  def classify(word) = camelize(singular(word))

  private

  def inflect(word, rules)
    return word if @table.uncountables.any? { word.downcase.match?(/\b#{Regexp.escape(it)}\z/) }
    rule, replacement = rules.find { |pattern, _| word.match?(pattern) }
    rule ? word.sub(rule, replacement) : word
  end

  def cased(part) = @table.acronyms.find { it.downcase == part } || part.capitalize
end
