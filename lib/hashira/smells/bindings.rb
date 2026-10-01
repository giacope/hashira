# frozen_string_literal: true

require "prism"
require_relative "conditions"
require_relative "refs"

class Hashira::Smells::Bindings
  READS = [Prism::LocalVariableReadNode, Prism::ItLocalVariableReadNode].freeze

  WRITES = [
    Prism::LocalVariableWriteNode, Prism::LocalVariableTargetNode, Prism::LocalVariableOperatorWriteNode,
    Prism::LocalVariableOrWriteNode, Prism::LocalVariableAndWriteNode
  ].freeze

  SCOPES = Hashira::Smells::Refs::SCOPES

  LOOPS = (SCOPES + Hashira::Smells::Conditions::LOOPS + [Prism::ForNode]).freeze

  Frame =
    Data.define(:scopes, :loops) do
      def enter(node) = with(scopes: nested(node, scopes, SCOPES), loops: nested(node, loops, LOOPS))

      def nested(node, stack, kinds) = kinds.include?(node.class) ? stack + [node] : stack

      def sighting(node)
        implicit = node.is_a?(Prism::ItLocalVariableReadNode)
        depth = implicit ? 0 : node.depth
        Sighting.new(node:, scope: scopes[-1 - depth], name: implicit ? :it : node.name, loops:)
      end
    end

  Sighting =
    Data.define(:node, :scope, :name, :loops) do
      def key = [scope.location.start_offset, name]

      def within?(loop) = loops.any? { it.equal?(loop) }

      def finish = node.location.end_offset

      def version(writes)
        loop = loops.reverse.find { |candidate| writes.any? { it.within?(candidate) } }
        [*key, loop&.location&.start_offset, writes.map(&:finish).select { it <= node.location.start_offset }.max]
      end
    end

  Ledger =
    Data.define(:reads, :written) do
      def note(node, frame)
        case node
        when *READS then reads[node] = frame.sighting(node)
        when *WRITES then record(frame.sighting(node))
        end
      end

      def record(write) = (written[write.key] ||= []) << write

      def writes(read) = written.fetch(read.key, [])
    end

  def initialize(definition)
    @definition = definition
  end

  def free(call) = sightings(call).reject { bound?(it, call) }.map { it.version(ledger.writes(it)) }

  private

  def sightings(call) = Hashira::Smells::Scope.inside(call).filter_map { ledger.reads[it] }

  def bound?(read, call) = call.location.start_offset <= read.scope.location.start_offset

  def ledger = @_ledger ||= survey

  def survey
    found = Ledger.new(reads: {}.compare_by_identity, written: {})
    walk(@definition, Frame.new(scopes: [@definition], loops: []), found)
    found
  end

  def walk(root, frame, ledger)
    root.compact_child_nodes.each do |child|
      next if Hashira::Smells::Scope::FENCES.include?(child.class)
      ledger.note(child, frame)
      walk(child, frame.enter(child), ledger)
    end
  end
end
