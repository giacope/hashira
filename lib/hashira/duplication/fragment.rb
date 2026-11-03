# frozen_string_literal: true

require "prism"

class Hashira::Duplication::Fragment
  SPOKEN = [Prism::CallNode, Prism::ConstantReadNode, Prism::ConstantPathNode].freeze

  WRITTEN = [Prism::StringNode, Prism::SymbolNode].freeze

  HEREDOCS = [Prism::StringNode, Prism::InterpolatedStringNode, Prism::XStringNode, Prism::InterpolatedXStringNode].freeze

  def initialize(file, roots, walks, setting)
    @file = file
    @roots = roots
    @walks = walks
    @setting = setting
  end

  def to_a = @roots

  def span = Hashira::Duplication::Span.new(@file, line, finish)

  def shape = Hashira::Duplication::Shape.new(types, muted)

  def words = Hashira::Duplication::Words.new(vocabulary, spoken)

  def body = Hashira::Duplication::Body.new(nodes, @setting)

  private

  def line = @_line ||= @roots.first.location.start_line

  def finish = @_finish ||= [@roots.last.location.end_line, *closings].max(1).fetch(0)

  def closings = nodes.select { heredoc?(it) }.map { it.closing_loc.start_line }

  def heredoc?(node) = HEREDOCS.include?(node.class) && node.heredoc?

  def nodes = @_nodes ||= @walks.nodes(@roots)

  def types = @_types ||= nodes.map(&:type)

  def muted = @_muted ||= @walks.muted(@roots).uniq.size

  def vocabulary = @_vocabulary ||= nodes.flat_map { said(it) }

  def spoken = @_spoken ||= vocabulary.tally

  def said(node)
    return [node.name] if SPOKEN.include?(node.class)
    WRITTEN.include?(node.class) ? Hashira::Analysis::Syntax::Word.new(node).to_s.scan(/\w+/) : []
  end
end
