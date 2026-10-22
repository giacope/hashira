# frozen_string_literal: true

require "prism"
require_relative "discards"
require_relative "scope"

class Hashira::Smells::Recheck
  Change =
    Data.define(:call, :command) do
      def settles?(atom, held) = held.include?(call.receiver.slice) && (follows?(atom) || locks?(atom))

      def follows?(atom) = command && call.location.end_offset <= atom.location.start_offset

      def locks?(atom)
        block = call.block
        block.is_a?(Prism::BlockNode) && Hashira::Smells::Scope.new(block).covers?(atom)
      end
    end

  def initialize(method)
    @method = method
  end

  def settled?(atom, held)
    Hashira::Smells::Scope.new(@method).covers?(atom) && changes.any? { it.settles?(atom, held) }
  end

  private

  def changes = @_changes ||= calls.select(&:receiver).map { Change.new(call: it, command: discards.include?(it)) }

  def calls = Hashira::Smells::Scope.new(@method).inside.grep(Prism::CallNode)

  def discards = @_discards ||= Hashira::Smells::Discards.new(@method)
end
