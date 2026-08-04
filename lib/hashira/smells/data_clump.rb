# frozen_string_literal: true

class Hashira::Smells::DataClump < Hashira::Smells::Check
  MAX_COPIES = 2

  MIN_SIZE = 2

  private

  def smelly? = clumps.any?

  def candidates = @candidates ||= subject.owned.map { [it, it.arguments.sort] }

  def clumps = @clumps ||= shared.map { |clump| [clump, holders(clump)] }

  def shared = candidates.combination(MAX_COPIES + 1).filter_map { |group| clump(group) }.uniq

  def clump(group)
    names = group.map(&:last).inject(:&)
    names if names.size >= MIN_SIZE
  end

  def holders(clump) = candidates.filter_map { |method, names| method if (clump - names).empty? }

  def evidence = clumps.map { |clump, holders| row(clump, holders) }

  def row(clump, holders)
    "(#{clump.join(", ")}) → #{holders.size} methods: #{holders.map { |holder| holder.node.name }.join(", ")}"
  end
end
