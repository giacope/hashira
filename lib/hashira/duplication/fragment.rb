# frozen_string_literal: true

require "digest"
require "prism"

class Hashira::Duplication::Fragment
  DIGEST_LENGTH = 12

  SCHEMA = %i[
    class_node module_node statements_node arguments_node assoc_node
    array_node hash_node keyword_hash_node constant_read_node constant_path_node
    symbol_node string_node integer_node float_node true_node false_node nil_node
  ].freeze

  def initialize(file, roots)
    @file = file
    @roots = roots
  end

  attr_reader :file

  def types = @_types ||= nodes.map(&:type)

  def digest = Digest::SHA256.hexdigest(shape).slice(0, DIGEST_LENGTH)

  def shape = types.join(",")

  def mass = types.size

  def schema? = nodes.all? { directive?(it) }

  def line = @roots.first.location.start_line

  def finish = @roots.last.location.end_line

  def location = "#{file}:#{line}"

  def range = "#{file}:#{line}-#{finish}"

  def rank = [file, line]

  def overlaps?(other) = file == other.file && line <= other.finish && other.line <= finish

  def touches?(others) = others.any? { overlaps?(it) }

  def nodes = @_nodes ||= @roots.flat_map { Hashira::Analysis::NodeWalk.collect(it) }

  private

  def directive?(node)
    return SCHEMA.include?(node.type) unless node.is_a?(Prism::CallNode)
    !node.receiver && !node.block && literals?(node.arguments)
  end

  def literals?(arguments) = Hashira::Duplication::Literal.new(arguments).literals?
end
