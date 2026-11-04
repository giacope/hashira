# frozen_string_literal: true

require "prism"

class Hashira::Smells::Memo
  WRITES = [Prism::LocalVariableWriteNode, Prism::InstanceVariableWriteNode].freeze

  def initialize(branch, check)
    @branch = branch
    @check = check
  end

  def fills?(held, method)
    return false if passed?(held, method)
    names = held.map(&:slice)
    blank, kept = sides.map { it && lines(it) }
    blank ? writes?(blank.last, names) && (kept.nil? || answers?(kept, names)) : guards?(kept, names, method)
  end

  private

  def passed?(held, method)
    given = method.accept(Hashira::Smells::Parameters).names
    held.any? { it.is_a?(Prism::LocalVariableReadNode) && given.include?(it.name) }
  end

  def sides
    case @branch
    when Prism::IfNode then tested? ? [@branch, @branch.subsequent] : []
    else unless_sides
    end
  end

  def unless_sides
    pair = [@branch, @branch.else_clause]
    return pair if @branch.equal?(@check)
    tested? ? pair.reverse : []
  end

  def tested? = @branch.predicate.equal?(@check)

  def lines(side)
    Array(side.statements&.body).flat_map { it.is_a?(Prism::ParenthesesNode) ? Hashira::Analysis::Syntax::Body.new(it).to_a : [it] }
  end

  def guards?(kept, names, method)
    returned = kept&.one? && kept.first.is_a?(Prism::ReturnNode) && kept.first.arguments
    returned && answers?(returned.arguments, names) && method.accept(Hashira::Analysis::Syntax::Body).to_a.any? { writes?(it, names) }
  end

  def answers?(found, names) = found.one? && names.include?(found.first.slice)

  def writes?(node, names) = WRITES.include?(node.class) && names.include?(node.name.to_s)
end
