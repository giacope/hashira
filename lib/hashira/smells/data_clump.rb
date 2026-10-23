# frozen_string_literal: true

require "prism"

class Hashira::Smells::DataClump < Hashira::Smells::Check
  MAX_COPIES = 2

  MIN_SIZE = 3

  DEFAULTED = [Prism::OptionalParameterNode, Prism::OptionalKeywordParameterNode].freeze

  INWARD = [NilClass, Prism::SelfNode].freeze

  private

  def smelly? = clumps.any?

  def candidates
    @_candidates ||= subject.owned.reject(&:polymorphic?).map { [it, carried(it).sort] }.select { clump(it.last) }
  end

  def carried(method) = method.arguments.reject { it.start_with?("_") } - defaulted(method.node)

  def defaulted(node)
    Hashira::Smells::Parameters.new(node).parts.filter_map { it.name if DEFAULTED.include?(it.class) }
  end

  def clumps = @_clumps ||= maximal.map { |clump| [clump, holders(clump)] }

  def maximal = flowing.reject { |clump| flowing.any? { |other| other != clump && (clump - other).empty? } }

  def flowing = @_flowing ||= shared.select { |clump| relayed?(clump) }

  def shared = pairs.flat_map { |pair| [pair, *narrowed(pair)] }.uniq.select { holders(it).size > MAX_COPIES }

  def pairs = candidates.map(&:last).combination(2).filter_map { |one, other| clump(one & other) }.uniq

  def narrowed(pair) = candidates.filter_map { |_, names| clump(pair & names) }

  def clump(names) = (names if names.size >= MIN_SIZE)

  def holders(clump) = candidates.filter_map { |method, names| method if (clump - names).empty? }

  def relayed?(clump)
    found = holders(clump)
    callees = found.map { it.node.name }
    found.any? { |holder| relays?(holder, clump, callees - [holder.node.name]) }
  end

  def relays?(holder, clump, callees)
    Hashira::Smells::Scope.new(holder.node).inside.grep(Prism::CallNode).any? do |call|
      callees.include?(call.name) && inward?(call.receiver) && (clump - handed(call)).empty?
    end
  end

  def inward?(receiver) = INWARD.include?(receiver.class)

  def handed(call)
    given = call.arguments
    given ? Hashira::Analysis::NodeWalk.new(given).collect.grep(Prism::LocalVariableReadNode).map(&:name) : []
  end

  def evidence = clumps.map { |clump, holders| row(clump, holders) }

  def row(clump, holders)
    "(#{clump.join(", ")}) → #{holders.size} methods: #{holders.map { |holder| holder.node.name }.join(", ")}"
  end
end
