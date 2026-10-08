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

  def windows = nodes.grep(Prism::StatementsNode).flat_map { sequence(it.body, setting(it)).fragments }

  def setting(statements) = bodies.fetch(statements, Hashira::Duplication::Setting::CODE)

  def bodies = @_bodies ||= scopes.grep(Prism::StatementsNode).to_h { [it, Hashira::Duplication::Setting.of(it)] }

  def scopes = nodes.filter_map { it.body if Hashira::Duplication::Sequence::SCOPES.include?(it.class) }

  def wholes = nodes.select { WHOLE.include?(it.class) } + arms

  def arms = nodes.grep(Prism::CaseNode).flat_map { sequence(it.conditions).unlisted }

  def sequence(statements, setting = Hashira::Duplication::Setting::CODE)
    Hashira::Duplication::Sequence.new(@file, statements, walks, setting)
  end
end
