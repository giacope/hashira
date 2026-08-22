# frozen_string_literal: true

class Hashira::Constraints::Declarations
  def initialize(list)
    @list = list
  end

  def empty? = @list.empty?

  def identity = @list.map(&:identity).sort

  def grants?(facts, paths)
    !paths.empty? && facts.all? { |fact| held?(fact, paths) }
  end

  def trouble(trees) = @list.filter_map { phrase(it, it.contradiction(trees)) }.first

  private

  def held?(fact, paths)
    reach = @list.select { it.name == fact }
    paths.all? { |path| reach.any? { it.covers?(path) } }
  end

  def phrase(declaration, found)
    "constraint #{declaration.name} is contradicted by #{found.file}:#{found.line}" if found
  end
end

Hashira::Constraints::Declarations::NONE = Hashira::Constraints::Declarations.new([].freeze)
