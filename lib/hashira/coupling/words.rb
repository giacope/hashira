# frozen_string_literal: true

require "prism"

class Hashira::Coupling::Words
  PATTERN = /\A[a-z][a-z_]*\z/

  class Literal
    def initialize(words, line)
      @words = words
      @line = line
    end

    def without(generic) = Literal.new(@words - generic, @line)

    def shared(other) = @words & other.words

    def holds?(words, share) = @words >= words && words.size >= share * @words.size

    def site(file) = "#{file}:#{@line}"

    protected

    attr_reader :words
  end

  def initialize(tree)
    @tree = tree
  end

  def lists
    Hashira::Analysis::NodeWalk.new(@tree).collect.filter_map do |node|
      words = entries(node).grep(PATTERN).to_set
      Literal.new(words, node.location.start_line) unless words.empty?
    end
  end

  private

  def entries(node)
    case node
    when Prism::ArrayNode then node.elements.flat_map { word(it) }
    when Prism::HashNode then keys(node)
    else []
    end
  end

  def keys(node) = node.elements.grep(Prism::AssocNode).flat_map { word(it.key) }

  def word(node) = Hashira::Analysis::Syntax::Word.new(node).to_a.map(&:to_s)
end
