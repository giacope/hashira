# frozen_string_literal: true

require "prism"
require_relative "bindings"
require_relative "endings"
require_relative "message"
require_relative "scope"

class Hashira::Smells::Course
  WRITES = [Prism::LocalVariableWriteNode, Prism::InstanceVariableWriteNode].freeze

  DRAWS = %i[
    gets getc getbyte getch readline readchar readbyte readpartial read_nonblock sysread
    recv recvfrom recv_nonblock recvmsg accept_nonblock pop shift deq
  ].freeze

  BANG = /\w!\z/

  CHANGES = (DRAWS + %i[<< push append unshift prepend insert concat delete delete_at delete_if clear replace]).freeze

  Stretch =
    Data.define(:first, :last, :held) do
      def ends = [first, last]

      def spans?(node) = first.location.end_offset <= node.location.end_offset && before?(node)

      def before?(node) = node.location.end_offset < last.location.end_offset && !covers?(last, node)

      def covers?(outer, node) = Hashira::Smells::Scope.new(outer).covers?(node)

      def aims?(call) = held.include?(call.receiver&.slice)

      def hands?(call) = handed(call).any? { held.include?(it.slice) }

      def handed(call) = Array(call.arguments&.arguments).flat_map { values(it) }.compact

      def values(argument) = argument.is_a?(Prism::KeywordHashNode) ? argument.elements.map(&:value) : [argument]

      def shifts?(node)
        case node
        when Prism::CallNode then aims?(node) && node.receiver.slice.start_with?("@") && moves?(node.name)
        when Prism::InstanceVariableWriteNode then held.include?(node.name.to_s)
        else false
        end
      end

      def moves?(name) = !name.end_with?("?") && name != first.name
    end

  def initialize(method, calls, discards, branches)
    @method = method
    @calls = calls
    @discards = discards
    @branches = branches
  end

  def parted?(pair)
    first, last = pair
    held = [first, *Hashira::Smells::Scope.new(first).inside].grep(Prism::CallNode).filter_map { it.receiver&.slice }
    stretch = Stretch.new(first:, last:, held:)
    left?(stretch) || disturbed?(stretch)
  end

  private

  def left?(stretch)
    @_endings ||= Hashira::Smells::Endings.new(@method.node)
    @_endings.parts?(stretch.first, stretch.last)
  end

  def disturbed?(stretch)
    disturbs?(stretch, moves) { stretch.aims?(it) } || disturbs?(stretch, steps) { stretch.hands?(it) } ||
      disturbs?(stretch, @calls) { |call| errands.own?(call) && errands.of(call.name).any? { stretch.shifts?(it) } }
  end

  def moves = @_moves ||= commands + @calls.select { changes?(Hashira::Smells::Message.new(it).name) }

  def changes?(name) = CHANGES.include?(name.to_sym) || BANG.match?(name)

  def errands = @_errands ||= Hashira::Smells::Errands.new(@method.home)

  def disturbs?(stretch, calls) = calls.any? { stretch.spans?(it) && meets?(it, stretch) && yield(it) }

  def commands = @_commands ||= @calls.select { @discards.include?(it) }

  def steps
    return @_steps if @_steps
    lists = Hashira::Smells::Scope.new(@method.node).inside.grep(Prism::StatementsNode)
    @_steps = commands + lists.flat_map(&:body).select { WRITES.include?(it.class) }.map(&:value).grep(Prism::CallNode)
  end

  def meets?(call, stretch) = stretch.ends.all? { @branches.together?([call, it]) }
end
