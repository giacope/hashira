# frozen_string_literal: true

require "prism"
require_relative "discards"
require_relative "postfix"
require_relative "scope"

class Hashira::Smells::Recheck
  Change =
    Data.define(:call, :command) do
      def settles?(atom, held, moment) = held.include?(call.receiver.slice) && (follows?(atom, moment) || locks?(atom))

      def follows?(atom, moment)
        command && call.location.start_offset < moment && !Hashira::Smells::Scope.new(call).covers?(atom)
      end

      def locks?(atom)
        block = call.block
        block.is_a?(Prism::BlockNode) && Hashira::Smells::Scope.new(block).covers?(atom)
      end
    end

  def initialize(method)
    @method = method
  end

  # A trailing condition is asked when its statement starts, before the statement runs.
  def settled?(atom, held)
    Hashira::Smells::Scope.new(@method).covers?(atom) &&
      (trailing.find { it.covers?(atom) }&.start || atom.location.start_offset).then do |moment|
        changes.any? { it.settles?(atom, held, moment) }
      end
  end

  private

  def trailing = @_trailing ||= inside.map { Hashira::Smells::Postfix.new(it) }.select(&:trailing?)

  def changes
    @_changes ||=
      Hashira::Smells::Discards.new(@method).then do |discards|
        inside.grep(Prism::CallNode).select(&:receiver).map { Change.new(call: it, command: discards.include?(it)) }
      end
  end

  def inside = @_inside ||= Hashira::Smells::Scope.new(@method).inside
end
