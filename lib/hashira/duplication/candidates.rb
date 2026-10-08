# frozen_string_literal: true

require "prism"

class Hashira::Duplication::Candidates
  WHOLE = [Prism::DefNode, Prism::RescueNode].freeze

  def initialize(file, tree)
    @file = file
    @tree = tree
  end

  def fragments = (windows + wholes.map { Hashira::Duplication::Fragment.new(@file, [it], walks) }).reject(&:sink?)

  private

  def nodes = @_nodes ||= Hashira::Analysis::NodeWalk.collect(@tree)

  def walks = @_walks ||= Hashira::Duplication::Walks.new

  def windows = runs.flat_map { sequence(it).fragments }

  def runs = nodes.filter_map { it.body if it.is_a?(Prism::StatementsNode) }

  def wholes = nodes.select { WHOLE.include?(it.class) } + arms

  def arms = nodes.grep(Prism::CaseNode).flat_map { sequence(it.conditions).unlisted }

  def sequence(statements) = Hashira::Duplication::Sequence.new(@file, statements, walks)
end
