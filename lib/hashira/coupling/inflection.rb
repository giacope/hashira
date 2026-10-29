# frozen_string_literal: true

class Hashira::Coupling::Inflection
  def initialize(table)
    @table = table
  end

  def plural(word) = @table.plural(word)

  def singular(word) = @table.singular(word)

  def camelize(word) = word.split("/").map { |part| part.split("_").map { @table.cased(it) }.join }.join("::")

  def classify(word) = camelize(singular(word))
end
