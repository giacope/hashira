# frozen_string_literal: true

require "digest"
require "prism"

class Hashira::Duplication::Fragment
  DIGEST_LENGTH = 12

  SCHEMA = %i[
    class_node module_node statements_node arguments_node assoc_node block_node
    array_node hash_node keyword_hash_node constant_read_node constant_path_node constant_write_node
    symbol_node string_node interpolated_string_node regular_expression_node
    integer_node float_node true_node false_node nil_node
  ].freeze

  HEREDOCS = [Prism::StringNode, Prism::InterpolatedStringNode, Prism::XStringNode, Prism::InterpolatedXStringNode].freeze

  def initialize(file, roots, walks)
    @file = file
    @roots = roots
    @walks = walks
  end

  attr_reader :file

  def types = @_types ||= nodes.map(&:type)

  def digest = Digest::SHA256.hexdigest(shape).slice(0, DIGEST_LENGTH)

  def shape = types.join(",")

  def mass = types.size

  def schema? = nodes.all? { directive?(it) }

  def sectioned? = bare?(@roots.first) && @roots[1].is_a?(Prism::DefNode)

  def line = @roots.first.location.start_line

  def finish = @_finish ||= [@roots.last.location.end_line, *closings].max

  def location = "#{file}:#{line}"

  def range = "#{file}:#{line}-#{finish}"

  def rank = [file, line]

  def overlaps?(other) = file == other.file && line <= other.finish && other.line <= finish

  def touches?(others) = others.any? { overlaps?(it) }

  def within?(others) = others.any? { covers?(it) }

  def nodes = @_nodes ||= @walks.nodes(@roots)

  private

  def covers?(other) = file == other.file && other.line <= line && finish <= other.finish

  def closings = nodes.select { heredoc?(it) }.map { it.closing_loc.start_line }

  def heredoc?(node) = HEREDOCS.include?(node.class) && node.heredoc?

  def directive?(node)
    return SCHEMA.include?(node.type) unless node.is_a?(Prism::CallNode)
    node.receiver ? constant?(node) : literals?(node.arguments)
  end

  def bare?(node) = node.is_a?(Prism::CallNode) && [node.receiver, node.arguments, node.block].none?

  def constant?(call) = !call.arguments && !call.block && Hashira::Duplication::Literal.new(call.receiver).literal?

  def literals?(arguments) = Hashira::Duplication::Literal.new(arguments).literals?
end
