# frozen_string_literal: true

class Hashira::Coupling::RollCall
  MIN_WORDS = 3

  MIN_FILES = 3

  MIN_PACKAGES = 2

  Roll = Data.define(:words, :files, :packages)

  def initialize(lists, homes)
    @lists = lists
    @homes = homes
  end

  def rolls = maximal(candidates.filter_map { entry(it) }).sort_by(&:words)

  private

  def files = @files ||= @lists.keys.sort

  def candidates
    files.combination(2).map { |one, two| @lists[one] & @lists[two] }.select { it.size >= MIN_WORDS }.uniq
  end

  def entry(words)
    holders = files.select { @lists[it] >= words }
    spread = holders.map { @homes[it] }.uniq.sort
    return unless holders.size >= MIN_FILES && spread.size >= MIN_PACKAGES
    Roll.new(words: words.sort, files: holders, packages: spread)
  end

  def maximal(rolls)
    rolls.reject { |roll| swallowed?(roll, rolls) }
  end

  def swallowed?(roll, rolls) = rolls.any? { swallows?(it, roll) }

  def swallows?(big, small)
    mine = big.words
    theirs = small.words
    mine != theirs && (theirs - mine).empty?
  end
end
