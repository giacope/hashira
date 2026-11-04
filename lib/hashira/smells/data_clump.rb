# frozen_string_literal: true

require "prism"

class Hashira::Smells::DataClump < Hashira::Smells::Check
  MAX_COPIES = 2

  MIN_SIZE = 3

  DEFAULTED = [Prism::OptionalParameterNode, Prism::OptionalKeywordParameterNode].freeze

  INWARD = [NilClass, Prism::SelfNode].freeze

  ADVICE = "Introduce a parameter object."

  private

  def smelly? = clumps.any?

  def detail = Hashira::Smells::Spot.new(site, "passes the same parameters between methods", ADVICE)

  def candidates
    @_candidates ||= owned.reject { it.standing.polymorphic? }.map { [it, carried(it).sort] }.select { clump?(it.last) }
  end

  def carried(method)
    method.accept(Hashira::Smells::Parameters).arguments.reject { it.start_with?("_") } - defaulted(method)
  end

  def defaulted(method) = method.accept(Hashira::Smells::Parameters).named(DEFAULTED)

  def clumps = @_clumps ||= maximal.map { |clump| [clump, holders(clump)] }

  def maximal = flowing.reject { |clump| flowing.any? { |other| other != clump && (clump - other).empty? } }

  def flowing = @_flowing ||= shared.select { |clump| relayed?(clump) }

  def shared = pairs.flat_map { |pair| [pair, *narrowed(pair)] }.uniq.select { holders(it).size > MAX_COPIES }

  def pairs = candidates.map(&:last).combination(2).map { |one, other| one & other }.select { clump?(it) }.uniq

  def narrowed(pair) = candidates.map { |_, names| pair & names }.select { clump?(it) }

  def clump?(names) = names.size >= MIN_SIZE

  def holders(clump) = candidates.filter_map { |method, names| method if (clump - names).empty? }

  def relayed?(clump)
    found = holders(clump)
    callees = found.map { selector(it) }
    found.any? { |holder| relays?(holder, clump, callees - [selector(holder)]) }
  end

  def relays?(holder, clump, callees)
    holder.accept(Hashira::Smells::Scope).inside.grep(Prism::CallNode).any? do |call|
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
    "(#{clump.join(", ")}) → #{holders.size} methods: #{holders.map { selector(it) }.join(", ")}"
  end
end
