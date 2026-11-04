# frozen_string_literal: true

require "prism"
require_relative "bindings"
require_relative "endings"
require_relative "message"
require_relative "scope"

class Hashira::Smells::Course
  WRITES = [Prism::LocalVariableWriteNode, Prism::InstanceVariableWriteNode].freeze

  class Stretch
    def initialize(first, last)
      @first = first
      @last = last
    end

    def disturbs?(calls, branches) = calls.any? { spans?(it) && met?(it, branches) && yield(it) }

    private

    def spans?(node) = @first.location.end_offset <= node.location.end_offset && before?(node)

    def before?(node) = node.location.end_offset < @last.location.end_offset && !covers?(@last, node)

    def covers?(outer, node) = Hashira::Smells::Extent.new(outer).covers?(node)

    def met?(call, branches) = [@first, @last].all? { branches.together?([call, it]) }
  end

  class Holdings
    def initialize(held, name)
      @held = held
      @name = name
    end

    def aims?(call) = @held.include?(call.receiver&.slice)

    def hands?(call) = handed(call).any? { @held.include?(it.slice) }

    def shifts?(node)
      case node
      when Prism::CallNode then aims?(node) && node.receiver.slice.start_with?("@") && moves?(node.name)
      when Prism::InstanceVariableWriteNode then @held.include?(node.name.to_s)
      else false
      end
    end

    private

    def handed(call) = Array(call.arguments&.arguments).flat_map { values(it) }.compact

    def values(argument) = argument.is_a?(Prism::KeywordHashNode) ? argument.elements.map(&:value) : [argument]

    def moves?(name) = !name.end_with?("?") && name != @name
  end

  def initialize(method, calls, discards, errands = method.home.accept(Hashira::Smells::Errands))
    @method = method
    @calls = calls
    @discards = discards
    @errands = errands
  end

  def disturbed?(pair, branches)
    first, last = pair
    held = [first, *Hashira::Smells::Scope.new(first).inside].grep(Prism::CallNode).filter_map { it.receiver&.slice }
    stretched(Stretch.new(first, last), Holdings.new(held, first.name), branches)
  end

  private

  def stretched(stretch, holdings, branches)
    stretch.disturbs?(moves, branches) { holdings.aims?(it) } ||
      stretch.disturbs?(steps, branches) { holdings.hands?(it) } ||
      stretch.disturbs?(@calls, branches) { |call| shifted?(call, holdings) }
  end

  def moves = @_moves ||= commands + @calls.select { Hashira::Smells::Message.new(it).changes? }

  def shifted?(call, holdings) = @errands.own?(call) && @errands.of(call.name).any? { holdings.shifts?(it) }

  def commands = @_commands ||= @calls.select { @discards.include?(it) }

  def steps
    return @_steps if @_steps
    lists = @method.accept(Hashira::Smells::Scope).inside.grep(Prism::StatementsNode)
    @_steps = commands + lists.flat_map(&:body).select { WRITES.include?(it.class) }.map(&:value).grep(Prism::CallNode)
  end
end
