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

  def nodes = @_nodes ||= Hashira::Analysis::NodeWalk.new(@tree).collect

  def walks = @_walks ||= Hashira::Duplication::Walks.new

  def windows
    reported = Hashira::Duplication::Recovery.of(nodes).map { it.clause.statements }
    code = Hashira::Duplication::Setting::CODE
    (nodes.grep(Prism::StatementsNode) - reported).flat_map { sequence(it.body, bodies.fetch(it, code)).fragments }
  end

  def bodies
    @_bodies ||=
      nodes.filter_map { it.body if Hashira::Duplication::Sequence::SCOPES.include?(it.class) }
        .grep(Prism::StatementsNode).to_h { [it, Hashira::Duplication::Setting.of(it)] }
  end

  def wholes
    arms = nodes.grep(Prism::CaseNode).flat_map { sequence(it.conditions).unlisted }
    nodes.select { WHOLE.include?(it.class) } + arms
  end

  def sequence(statements, setting = Hashira::Duplication::Setting::CODE)
    Hashira::Duplication::Sequence.new(@file, statements, walks, setting)
  end
end
