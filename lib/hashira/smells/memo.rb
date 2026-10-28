# frozen_string_literal: true

require "prism"

class Hashira::Smells::Memo
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
    given = Hashira::Smells::Parameters.new(method).names
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
    Array(side.statements&.body).flat_map { it.is_a?(Prism::ParenthesesNode) ? Hashira::Analysis::Syntax.new(it).statements : [it] }
  end

  def guards?(kept, names, method)
    returned = kept&.one? && kept.first.is_a?(Prism::ReturnNode) && kept.first.arguments
    returned && answers?(returned.arguments, names) && Hashira::Analysis::Syntax.new(method).statements.any? { writes?(it, names) }
  end

  def answers?(found, names) = found.one? && names.include?(found.first.slice)

  def writes?(node, names) = Hashira::Smells::Course::WRITES.include?(node.class) && names.include?(node.name.to_s)
end
