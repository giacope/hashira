# frozen_string_literal: true

class Hashira::Coupling::RollCall
  MIN_WORDS = 3

  MIN_FILES = 3

  MIN_PACKAGES = 2

  SHARE = 0.6

  GENERIC = %w[
    id created_at updated_at type name properties required items description title enum format default minimum
    maximum pattern additional_properties
  ].to_set.freeze

  Roll = Data.define(:words, :files, :packages, :sites)

  def initialize(lists, homes)
    @raw = lists
    @homes = homes
  end

  def rolls
    found = candidates.filter_map { entry(it) }
    found.reject { |roll| swallowed?(roll, found) }.sort_by(&:words)
  end

  private

  def lists = @_lists ||= @raw.transform_values { |literals| literals.map { it.with(words: it.words - GENERIC) } }

  def files = @_files ||= lists.keys.sort

  def candidates
    pairs = files.combination(2).flat_map { |one, two| lists[one].product(lists[two]) }
    pairs.filter_map { |mine, theirs| shared(mine, theirs) }.uniq
  end

  def shared(mine, theirs)
    words = mine.words & theirs.words
    words if words.size >= MIN_WORDS && most?(words, mine) && most?(words, theirs)
  end

  def most?(words, literal) = words.size >= SHARE * literal.words.size

  def holding(file, words) = lists[file].find { it.words >= words && most?(words, it) }

  def entry(words)
    holders = files.select { holding(it, words) }
    spread = holders.map { @homes[it] }.uniq.sort
    return unless holders.size >= MIN_FILES && spread.size >= MIN_PACKAGES
    sites = holders.map { "#{it}:#{holding(it, words).line}" }
    Roll.new(words: words.sort, files: holders, packages: spread, sites:)
  end

  def swallowed?(roll, rolls) = rolls.any? { swallows?(it, roll) }

  def swallows?(big, small)
    mine = big.words
    theirs = small.words
    mine != theirs && (theirs - mine).empty?
  end
end
