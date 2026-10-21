# frozen_string_literal: true

require "prism"

class Hashira::Coupling::Manifest
  RELATIVE = %i[require_relative].freeze

  LOADS = %i[require load autoload].freeze

  SOURCE = ".rb"

  def initialize(file, tree)
    @file = file
    @tree = tree
  end

  def names?(other) = relative.include?("/#{other}") || mentioned.any? { it.end_with?("/#{other}") }

  private

  def relative = @_relative ||= loaded(RELATIVE).map { File.expand_path(source(it), File.dirname("/#{@file}")) }

  def mentioned = @_mentioned ||= (loaded(LOADS) + listed).map { "/#{source(it)}" }

  def nodes = @_nodes ||= Hashira::Analysis::NodeWalk.collect(@tree)

  def loaded(names) = nodes.grep(Prism::CallNode).select { names.include?(it.name) }.filter_map { named(it) }

  def named(call) = Array(call.arguments&.arguments).grep(Prism::StringNode).map { text(it) }.last

  def listed = nodes.grep(Prism::StringNode).map { text(it) }.select { it.end_with?(SOURCE) }

  def source(text) = "#{text.delete_suffix(SOURCE)}#{SOURCE}"

  def text(node) = Hashira::Analysis::Syntax.text(node)
end
