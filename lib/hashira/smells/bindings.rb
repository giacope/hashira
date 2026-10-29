# frozen_string_literal: true

require "prism"
require_relative "conditions"
require_relative "postfix"
require_relative "refs"

class Hashira::Smells::Bindings
  READS = [Prism::LocalVariableReadNode, Prism::ItLocalVariableReadNode, Prism::InstanceVariableReadNode].freeze

  WRITES = [
    Prism::LocalVariableWriteNode, Prism::LocalVariableTargetNode, Prism::LocalVariableOperatorWriteNode,
    Prism::LocalVariableOrWriteNode, Prism::LocalVariableAndWriteNode,
    Prism::InstanceVariableWriteNode, Prism::InstanceVariableTargetNode, Prism::InstanceVariableOperatorWriteNode,
    Prism::InstanceVariableOrWriteNode, Prism::InstanceVariableAndWriteNode
  ].freeze

  IVARS = [
    Prism::InstanceVariableReadNode, Prism::InstanceVariableWriteNode, Prism::InstanceVariableTargetNode,
    Prism::InstanceVariableOperatorWriteNode, Prism::InstanceVariableOrWriteNode, Prism::InstanceVariableAndWriteNode
  ].freeze

  class Frame
    def initialize(scopes:, loops:, moment:)
      @scopes = scopes
      @loops = loops
      @moment = moment
    end

    def enter(node)
      scope = Hashira::Smells::Scope.new(node)
      loops = nested(node, @loops, scope.loop?)
      Frame.new(scopes: nested(node, @scopes, scope.closure?), loops:, moment: @moment)
    end

    def at(moment) = Frame.new(scopes: @scopes, loops: @loops, moment:)

    def sighting(node)
      implicit = node.is_a?(Prism::ItLocalVariableReadNode)
      location = node.location
      Sighting.new(
        scope: holder(node, implicit), name: implicit ? :it : node.name, loops: @loops,
        span: @moment ? [@moment, @moment] : [location.start_offset, location.end_offset]
      )
    end

    private

    def nested(node, stack, opened) = opened ? stack + [node] : stack

    def holder(node, implicit)
      return @scopes.fetch(0) if IVARS.include?(node.class)
      @scopes.fetch(-1 - (implicit ? 0 : node.depth))
    end
  end

  class Sighting
    def initialize(scope:, name:, loops:, span:)
      @scope = scope
      @name = name
      @loops = loops
      @span = span
    end

    def key = [@scope.location.start_offset, @name]

    def version(writes)
      loop = @loops.reverse.find { |candidate| writes.any? { it.within?(candidate) } }
      [*key, loop&.location&.start_offset, writes.map(&:finish).select { it <= @span.first }.max]
    end

    def bound?(call) = call.location.start_offset <= @scope.location.start_offset

    def finish = @span.fetch(1)

    protected

    def within?(loop) = @loops.any? { it.equal?(loop) }
  end

  class Ledger
    def initialize(notes)
      @notes = notes
    end

    def writes(read) = written.fetch(read.key, [])

    def sightings(nodes) = nodes.filter_map { reads[it] }

    private

    def reads = @_reads ||= noted(READS).to_h { |node, frame| [node, frame.sighting(node)] }.compare_by_identity

    def written = @_written ||= noted(WRITES).map { |node, frame| frame.sighting(node) }.group_by(&:key)

    def noted(kinds) = @notes.select { |node, _frame| kinds.include?(node.class) }
  end

  def initialize(definition)
    @definition = definition
  end

  def free(call) = sightings(call).reject { it.bound?(call) }.map { it.version(ledger.writes(it)) }

  private

  def sightings(call) = ledger.sightings(Hashira::Smells::Scope.new(call).inside)

  def ledger = @_ledger ||= survey

  def survey = Ledger.new(notes(@definition, Frame.new(scopes: [@definition], loops: [], moment: nil)))

  def notes(root, frame)
    root.compact_child_nodes.reject { Hashira::Smells::Scope.new(it).fence? }.flat_map do |child|
      timed = asked?(root, child) ? frame.at(root.location.start_offset) : frame
      [[child, timed], *notes(child, timed.enter(child))]
    end
  end

  def asked?(root, child) = Hashira::Smells::Postfix.new(root).asks?(child)
end
