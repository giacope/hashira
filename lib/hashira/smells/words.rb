# frozen_string_literal: true

class Hashira::Smells::Words
  def initialize(
    trees, vocabulary = Hashira::Smells::Vocabulary.new(trees), repertoire = Hashira::Smells::Repertoire.new(trees),
    values = Hashira::Smells::Values.new(trees)
  )
    @vocabulary = vocabulary
    @repertoire = repertoire
    @values = values
  end

  def speaks?(message) = @vocabulary.speaks?(message)

  def of(segments) = @repertoire.of(segments)

  def closed?(segments) = @repertoire.closed?(segments)

  def value?(name) = @values.include?(name)
end
