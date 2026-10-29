# frozen_string_literal: true

require "prism"

class Hashira::Duplication::Candidates
  TYPES = [Prism::ClassNode, Prism::ModuleNode, Prism::SingletonClassNode].freeze

  WHOLE = [Prism::DefNode, Prism::RescueNode].freeze

  def initialize(file, tree, walks = Hashira::Duplication::Walks.new)
    @file = file
    @tree = tree
    @walks = walks
  end

  def fragments
    kept = wholes.reject { sink?(it) }
    windows + kept.map { Hashira::Duplication::Fragment.new(@file, [it], @walks, code) }
  end

  private

  def nodes = @_nodes ||= Hashira::Analysis::NodeWalk.new(@tree).collect

  def windows
    reported = Hashira::Duplication::Recovery.of(nodes).map(&:statements)
    (nodes.grep(Prism::StatementsNode) - reported).flat_map { sequence(it.body, bodies.fetch(it, code)).fragments }
  end

  def bodies
    @_bodies ||=
      nodes.filter_map { it.body if TYPES.include?(it.class) }
        .grep(Prism::StatementsNode).to_h { [it, Hashira::Duplication::Setting.of(it)] }
  end

  def wholes
    arms = nodes.grep(Prism::CaseNode).flat_map { sequence(it.conditions, code).unlisted }
    nodes.select { WHOLE.include?(it.class) } + arms
  end

  def code = Hashira::Duplication::Setting.new(declarative: false, recurring: [])

  def sink?(node)
    statements = Hashira::Duplication::Statements.new([node]).to_a
    statements.one? && Hashira::Duplication::Sink.new(statements.first).sink?
  end

  def sequence(statements, setting)
    Hashira::Duplication::Sequence.new(@file, statements, @walks, setting)
  end
end
